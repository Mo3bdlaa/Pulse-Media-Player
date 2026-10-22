#include "player.hpp"
#include "engine.hpp"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QPointer>
#include <QVariantMap>
#include <cmath>
#include <vector>

#include <vlc/vlc.h>

namespace pulse {

namespace {

// libVLC 4 uses microseconds for every public time value; Pulse uses ms.
constexpr qint64 toMs(libvlc_time_t t) { return t / 1000; }
constexpr libvlc_time_t toCore(qint64 ms) { return libvlc_time_t(ms) * 1000; }

QString takeString(char *s)
{
    if (!s)
        return {};
    QString out = QString::fromUtf8(s);
    libvlc_free(s);
    return out;
}

libvlc_track_type_t toCoreTrackType(int type)
{
    switch (type) {
    case Player::VideoTrack: return libvlc_track_video;
    case Player::AudioTrack: return libvlc_track_audio;
    case Player::SubtitleTrack: return libvlc_track_text;
    }
    return libvlc_track_unknown;
}

QString fourccToString(uint32_t fourcc)
{
    QString s;
    for (int i = 0; i < 4; ++i) {
        const char c = char((fourcc >> (8 * i)) & 0xff);
        if (c > ' ')
            s += QLatin1Char(c);
    }
    return s;
}

} // namespace

struct Player::Private
{
    Player *q = nullptr;
    libvlc_media_player_t *mp = nullptr;
    libvlc_equalizer_t *equalizer = nullptr;

    State state = Idle;
    QUrl url;
    QString error;
    qint64 time = 0;
    qint64 length = 0;
    double position = 0.0;
    double buffering = 1.0;
    int caps = 0;
    int volume = 100;
    bool muted = false;
    double rate = 1.0;

    QString title, artist, album, genre, date;
    QUrl artwork;

    QVariantList videoTracks, audioTracks, subtitleTracks;
    QString currentAudio, currentSubtitle;
    QVariantList chapters;
    int currentChapter = -1;

    qint64 audioDelay = 0;
    qint64 subtitleDelay = 0;
    qint64 loopA = -1;
    qint64 loopB = -1;

    int brightness = 0, contrast = 0, saturation = 0, hue = 0, gamma = 0;
    QString aspect, crop;
    int deinterlace = -1;

    int eqPreset = -1;
    bool eqEnabled = false;
    QVariantList eqAmps;
    double eqPreamp = 0.0;
    double boost = 0.0; // dB added to the preamp ("Ultra Volume")

    QVariantList audioDevices;
    std::vector<std::shared_ptr<void>> keepAlive;

    // Runs `fn` on the player's thread. Core callbacks come from core threads.
    template <typename Fn>
    void post(Fn &&fn)
    {
        QPointer<Player> guard(q);
        QMetaObject::invokeMethod(q, [guard, fn = std::forward<Fn>(fn)]() {
            if (guard)
                fn();
        }, Qt::QueuedConnection);
    }

    void setState(State s)
    {
        if (state == s)
            return;
        state = s;
        emit q->stateChanged();
    }

    void refreshCaps()
    {
        int c = 0;
        if (libvlc_media_player_is_seekable(mp))
            c |= libvlc_capability_seek;
        if (libvlc_media_player_can_pause(mp))
            c |= libvlc_capability_pause;
        c |= libvlc_capability_change_rate;
        if (c != caps) {
            caps = c;
            emit q->capabilitiesChanged();
        }
    }

    QVariantList readTracks(libvlc_track_type_t type, QString *selectedId)
    {
        QVariantList list;
        libvlc_media_tracklist_t *tracks = libvlc_media_player_get_tracklist(mp, type, false);
        if (!tracks)
            return list;
        const size_t count = libvlc_media_tracklist_count(tracks);
        for (size_t i = 0; i < count; ++i) {
            const libvlc_media_track_t *t = libvlc_media_tracklist_at(tracks, i);
            QVariantMap m;
            const QString id = QString::fromUtf8(t->psz_id);
            const QString lang = QString::fromUtf8(t->psz_language);
            QString name = QString::fromUtf8(t->psz_name);
            if (name.isEmpty())
                name = lang.isEmpty() ? QStringLiteral("Track %1").arg(i + 1) : lang;
            m[QStringLiteral("id")] = id;
            m[QStringLiteral("name")] = name;
            m[QStringLiteral("language")] = lang;
            m[QStringLiteral("description")] = QString::fromUtf8(t->psz_description);
            m[QStringLiteral("selected")] = t->selected;
            m[QStringLiteral("codec")] = fourccToString(t->i_codec);
            const char *codecName = libvlc_media_get_codec_description(t->i_type, t->i_codec);
            m[QStringLiteral("codecName")] = QString::fromUtf8(codecName ? codecName : "");
            m[QStringLiteral("bitrate")] = t->i_bitrate;
            if (t->i_type == libvlc_track_video && t->u.video) {
                m[QStringLiteral("width")] = t->u.video->i_width;
                m[QStringLiteral("height")] = t->u.video->i_height;
                if (t->u.video->i_frame_rate_den)
                    m[QStringLiteral("frameRate")] = double(t->u.video->i_frame_rate_num)
                                                    / t->u.video->i_frame_rate_den;
            } else if (t->i_type == libvlc_track_audio && t->u.audio) {
                m[QStringLiteral("channels")] = t->u.audio->i_channels;
                m[QStringLiteral("sampleRate")] = t->u.audio->i_rate;
            }
            if (t->selected && selectedId && selectedId->isEmpty())
                *selectedId = id;
            list << m;
        }
        libvlc_media_tracklist_delete(tracks);
        return list;
    }

    void refreshTracks()
    {
        QString unusedVideo;
        currentAudio.clear();
        currentSubtitle.clear();
        videoTracks = readTracks(libvlc_track_video, &unusedVideo);
        audioTracks = readTracks(libvlc_track_audio, &currentAudio);
        subtitleTracks = readTracks(libvlc_track_text, &currentSubtitle);
        emit q->tracksChanged();
    }

    void refreshChapters()
    {
        chapters.clear();
        libvlc_chapter_description_t **descs = nullptr;
        const int count = libvlc_media_player_get_full_chapter_descriptions(mp, -1, &descs);
        for (int i = 0; i < count; ++i) {
            QVariantMap c;
            QString name = QString::fromUtf8(descs[i]->psz_name);
            if (name.isEmpty())
                name = QStringLiteral("Chapter %1").arg(i + 1);
            c[QStringLiteral("name")] = name;
            c[QStringLiteral("time")] = toMs(descs[i]->i_time_offset);
            c[QStringLiteral("duration")] = toMs(descs[i]->i_duration);
            chapters << c;
        }
        if (count > 0)
            libvlc_chapter_descriptions_release(descs, unsigned(count));
        currentChapter = count > 0 ? libvlc_media_player_get_chapter(mp) : -1;
        emit q->chaptersChanged();
    }

    void refreshMeta()
    {
        libvlc_media_t *media = libvlc_media_player_get_media(mp);
        if (!media)
            return;
        title = takeString(libvlc_media_get_meta(media, libvlc_meta_Title));
        artist = takeString(libvlc_media_get_meta(media, libvlc_meta_Artist));
        album = takeString(libvlc_media_get_meta(media, libvlc_meta_Album));
        genre = takeString(libvlc_media_get_meta(media, libvlc_meta_Genre));
        date = takeString(libvlc_media_get_meta(media, libvlc_meta_Date));
        const QString art = takeString(libvlc_media_get_meta(media, libvlc_meta_ArtworkURL));
        // Only local artwork (embedded or cached next to the media) is used here;
        // online enrichment is an opt-in service outside the engine.
        artwork = art.startsWith(QLatin1String("file:")) || art.startsWith(QLatin1String("attachment:"))
                      ? QUrl(art) : QUrl();
        libvlc_media_release(media);
        if (title.isEmpty())
            title = url.isLocalFile() ? QFileInfo(url.toLocalFile()).completeBaseName()
                                      : url.fileName().isEmpty() ? url.toDisplayString() : url.fileName();
        emit q->metaChanged();
    }

    void applyAudioState()
    {
        libvlc_audio_set_volume(mp, volume);
        libvlc_audio_set_mute(mp, muted ? 1 : 0);
    }

    void applyAdjust()
    {
        const bool any = brightness || contrast || saturation || hue || gamma;
        libvlc_video_set_adjust_int(mp, libvlc_adjust_Enable, any ? 1 : 0);
        if (!any)
            return;
        libvlc_video_set_adjust_float(mp, libvlc_adjust_Brightness, 1.0f + brightness / 100.0f);
        libvlc_video_set_adjust_float(mp, libvlc_adjust_Contrast, 1.0f + contrast / 100.0f);
        libvlc_video_set_adjust_float(mp, libvlc_adjust_Saturation, 1.0f + saturation / 100.0f);
        libvlc_video_set_adjust_float(mp, libvlc_adjust_Hue, float(hue));
        libvlc_video_set_adjust_float(mp, libvlc_adjust_Gamma, float(std::pow(10.0, gamma / 100.0)));
        emit q->adjustChanged();
    }

    // The core copies the settings, so a temporary combines the user's
    // equalizer with the boost without touching either.
    void applyEqualizer()
    {
        if (!mp)
            return;
        if (!eqEnabled && boost <= 0.0) {
            libvlc_media_player_set_equalizer(mp, nullptr);
            return;
        }
        libvlc_equalizer_t *effective = libvlc_audio_equalizer_new();
        const unsigned bands = libvlc_audio_equalizer_get_band_count();
        if (eqEnabled)
            for (unsigned i = 0; i < bands; ++i)
                libvlc_audio_equalizer_set_amp_at_index(effective, libvlc_audio_equalizer_get_amp_at_index(equalizer, i), i);
        const double pre = (eqEnabled ? double(libvlc_audio_equalizer_get_preamp(equalizer)) : 0.0) + boost;
        libvlc_audio_equalizer_set_preamp(effective, float(qBound(-20.0, pre, 20.0)));
        libvlc_media_player_set_equalizer(mp, effective);
        libvlc_audio_equalizer_release(effective);
    }

    void readEqualizer()
    {
        eqAmps.clear();
        const unsigned bands = libvlc_audio_equalizer_get_band_count();
        for (unsigned i = 0; i < bands; ++i)
            eqAmps << double(libvlc_audio_equalizer_get_amp_at_index(equalizer, i));
        eqPreamp = libvlc_audio_equalizer_get_preamp(equalizer);
    }

    // --- core callbacks (core threads) ---

    static Private *self(void *opaque) { return static_cast<Private *>(opaque); }

    static void onMediaStopping(void *opaque, libvlc_media_t *, libvlc_stopping_reason_t reason)
    {
        Private *p = self(opaque);
        p->post([p, reason]() {
            if (reason == libvlc_stopping_reason_eos)
                emit p->q->endReached();
            else if (reason == libvlc_stopping_reason_error) {
                p->error = Player::tr("This media could not be played.");
                p->setState(Error);
                emit p->q->errorOccurred(p->error);
            }
        });
    }

    static void onStateChanged(void *opaque, libvlc_state_t s)
    {
        Private *p = self(opaque);
        p->post([p, s]() {
            switch (s) {
            case libvlc_NothingSpecial: p->setState(Idle); break;
            case libvlc_Opening: p->setState(Opening); break;
            case libvlc_Playing:
                p->applyAudioState();
                p->refreshCaps();
                p->refreshMeta();
                p->setState(Playing);
                break;
            case libvlc_Paused: p->setState(Paused); break;
            case libvlc_Stopping:
            case libvlc_Stopped:
                if (p->state != Error)
                    p->setState(Stopped);
                break;
            case libvlc_Error:
                p->error = Player::tr("This media could not be played.");
                p->setState(Error);
                emit p->q->errorOccurred(p->error);
                break;
            }
        });
    }

    static void onBuffering(void *opaque, float value)
    {
        Private *p = self(opaque);
        p->post([p, value]() {
            p->buffering = value;
            emit p->q->bufferingChanged();
        });
    }

    static void onRate(void *opaque, float rate)
    {
        Private *p = self(opaque);
        p->post([p, rate]() {
            p->rate = rate;
            emit p->q->rateChanged();
        });
    }

    static void onCapabilities(void *opaque, libvlc_capability_t, libvlc_capability_t caps)
    {
        Private *p = self(opaque);
        p->post([p, caps]() {
            if (p->caps != int(caps)) {
                p->caps = int(caps);
                emit p->q->capabilitiesChanged();
            }
        });
    }

    static void onPosition(void *opaque, libvlc_time_t time, double pos)
    {
        Private *p = self(opaque);
        p->post([p, time, pos]() {
            p->time = toMs(time);
            p->position = pos;
            emit p->q->timeChanged();
        });
    }

    static void onLength(void *opaque, libvlc_time_t length)
    {
        Private *p = self(opaque);
        p->post([p, length]() {
            p->length = toMs(length);
            emit p->q->lengthChanged();
        });
    }

    static void onTrackList(void *opaque, libvlc_list_action_t, libvlc_track_type_t, const char *)
    {
        Private *p = self(opaque);
        p->post([p]() { p->refreshTracks(); });
    }

    static void onTrackSelection(void *opaque, libvlc_track_type_t, const char *, const char *)
    {
        Private *p = self(opaque);
        p->post([p]() { p->refreshTracks(); });
    }

    static void onTitles(void *opaque)
    {
        Private *p = self(opaque);
        p->post([p]() { p->refreshChapters(); });
    }

    static void onTitleSelection(void *opaque, const libvlc_title_description_t *, unsigned)
    {
        Private *p = self(opaque);
        p->post([p]() { p->refreshChapters(); });
    }

    static void onChapterSelection(void *opaque, const libvlc_title_description_t *, unsigned,
                                   const libvlc_chapter_description_t *, unsigned chapter)
    {
        Private *p = self(opaque);
        p->post([p, chapter]() {
            p->currentChapter = int(chapter);
            emit p->q->chaptersChanged();
        });
    }

    static void onScreenshot(void *opaque, const char *path)
    {
        Private *p = self(opaque);
        const QString file = QString::fromUtf8(path);
        p->post([p, file]() { emit p->q->snapshotSaved(file); });
    }

    static void onMeta(void *opaque, libvlc_media_t *)
    {
        Private *p = self(opaque);
        p->post([p]() { p->refreshMeta(); });
    }

    // Lives for the whole process: libVLC keeps the pointer, it does not copy.
    static const libvlc_media_player_cbs *callbacks()
    {
        static const libvlc_media_player_cbs cbs = [] {
            libvlc_media_player_cbs c{};
            c.version = 0;
            c.on_media_stopping = onMediaStopping;
            c.on_state_changed = onStateChanged;
            c.on_buffering_changed = onBuffering;
            c.on_rate_changed = onRate;
            c.on_capabilities_changed = onCapabilities;
            c.on_position_changed = onPosition;
            c.on_length_changed = onLength;
            c.on_track_list_changed = onTrackList;
            c.on_track_selection_changed = onTrackSelection;
            c.on_titles_changed = onTitles;
            c.on_title_selection_changed = onTitleSelection;
            c.on_chapter_selection_changed = onChapterSelection;
            c.on_screenshot_taken = onScreenshot;
            c.on_media_parsed = onMeta;
            c.on_media_meta_changed = onMeta;
            return c;
        }();
        return &cbs;
    }
};

Player::Player(QObject *parent)
    : QObject(parent)
    , d(std::make_unique<Private>())
{
    d->q = this;
    Engine *engine = Engine::instance();
    auto *vlc = engine ? static_cast<libvlc_instance_t *>(engine->nativeHandle()) : nullptr;
    if (!vlc) {
        qWarning("pulse: Player created without a ready Engine");
        return;
    }
    d->mp = libvlc_media_player_new(vlc, Private::callbacks(), d.get());
    d->equalizer = libvlc_audio_equalizer_new();
    d->readEqualizer();
}

Player::~Player()
{
    if (d->mp) {
        libvlc_media_player_stop_async(d->mp);
        libvlc_media_player_release(d->mp);
        d->mp = nullptr;
    }
    d->keepAlive.clear();
    if (d->equalizer)
        libvlc_audio_equalizer_release(d->equalizer);
}

Player::State Player::state() const { return d->state; }
bool Player::isPlaying() const { return d->state == Playing; }
bool Player::hasMedia() const { return !d->url.isEmpty(); }
QUrl Player::url() const { return d->url; }
QString Player::errorString() const { return d->error; }
qint64 Player::time() const { return d->time; }
qint64 Player::length() const { return d->length; }
double Player::position() const { return d->position; }
double Player::buffering() const { return d->buffering; }
bool Player::isSeekable() const { return d->caps & libvlc_capability_seek; }
bool Player::isPausable() const { return d->caps & libvlc_capability_pause; }
bool Player::isRateChangeable() const { return d->caps & libvlc_capability_change_rate; }
int Player::volume() const { return d->volume; }
bool Player::isMuted() const { return d->muted; }
double Player::rate() const { return d->rate; }
QString Player::title() const { return d->title; }
QString Player::artist() const { return d->artist; }
QString Player::album() const { return d->album; }
QString Player::genre() const { return d->genre; }
QString Player::date() const { return d->date; }
QUrl Player::artworkUrl() const { return d->artwork; }
bool Player::hasVideo() const { return !d->videoTracks.isEmpty(); }
QVariantList Player::videoTracks() const { return d->videoTracks; }
QVariantList Player::audioTracks() const { return d->audioTracks; }
QVariantList Player::subtitleTracks() const { return d->subtitleTracks; }
QString Player::currentAudioTrack() const { return d->currentAudio; }
QString Player::currentSubtitleTrack() const { return d->currentSubtitle; }
QVariantList Player::chapters() const { return d->chapters; }
int Player::currentChapter() const { return d->currentChapter; }
qint64 Player::audioDelay() const { return d->audioDelay; }
qint64 Player::subtitleDelay() const { return d->subtitleDelay; }
qint64 Player::loopA() const { return d->loopA; }
qint64 Player::loopB() const { return d->loopB; }
int Player::brightness() const { return d->brightness; }
int Player::contrast() const { return d->contrast; }
int Player::saturation() const { return d->saturation; }
int Player::hue() const { return d->hue; }
int Player::gamma() const { return d->gamma; }
QString Player::aspectRatio() const { return d->aspect; }
QString Player::cropRatio() const { return d->crop; }
int Player::deinterlace() const { return d->deinterlace; }
int Player::equalizerPreset() const { return d->eqPreset; }
bool Player::isEqualizerEnabled() const { return d->eqEnabled; }
QVariantList Player::equalizerAmps() const { return d->eqAmps; }
double Player::equalizerPreamp() const { return d->eqPreamp; }
double Player::boost() const { return d->boost; }

void Player::setBoost(double db)
{
    db = qBound(0.0, db, 12.0);
    if (qFuzzyCompare(db + 1.0, d->boost + 1.0))
        return;
    d->boost = db;
    d->applyEqualizer();
    emit volumeChanged();
}
QVariantList Player::audioDevices() const { return d->audioDevices; }
void *Player::nativeHandle() const { return d->mp; }
void Player::keepAlive(std::shared_ptr<void> object) { d->keepAlive.push_back(std::move(object)); }

void Player::open(const QUrl &url, qint64 startTimeMs)
{
    if (!d->mp || url.isEmpty())
        return;

    libvlc_media_t *media = url.isLocalFile()
        ? libvlc_media_new_path(QDir::toNativeSeparators(url.toLocalFile()).toUtf8().constData())
        : libvlc_media_new_location(url.toString(QUrl::FullyEncoded).toUtf8().constData());
    if (!media) {
        d->error = tr("This address could not be opened.");
        d->setState(Error);
        emit errorOccurred(d->error);
        return;
    }
    if (startTimeMs > 0)
        libvlc_media_add_option(media, QStringLiteral(":start-time=%1")
                                           .arg(startTimeMs / 1000.0, 0, 'f', 3)
                                           .toUtf8().constData());

    d->url = url;
    d->error.clear();
    d->time = startTimeMs;
    d->length = 0;
    d->position = 0.0;
    d->title = url.isLocalFile() ? QFileInfo(url.toLocalFile()).completeBaseName() : url.fileName();
    d->artist.clear();
    d->album.clear();
    d->genre.clear();
    d->date.clear();
    d->artwork.clear();
    d->videoTracks.clear();
    d->audioTracks.clear();
    d->subtitleTracks.clear();
    d->chapters.clear();
    d->currentChapter = -1;
    d->loopA = d->loopB = -1;

    libvlc_media_player_set_media(d->mp, media);
    libvlc_media_release(media);

    emit mediaChanged();
    emit metaChanged();
    emit tracksChanged();
    emit chaptersChanged();
    emit loopChanged();
    emit timeChanged();
    emit lengthChanged();

    d->setState(Opening);
    libvlc_media_player_play(d->mp);
}

void Player::play()
{
    if (d->mp)
        libvlc_media_player_play(d->mp);
}

void Player::pause()
{
    if (d->mp)
        libvlc_media_player_set_pause(d->mp, 1);
}

void Player::togglePause()
{
    if (!d->mp)
        return;
    if (d->state == Playing)
        libvlc_media_player_set_pause(d->mp, 1);
    else if (d->state == Paused)
        libvlc_media_player_set_pause(d->mp, 0);
    else if (!d->url.isEmpty())
        open(d->url);
}

void Player::stop()
{
    if (d->mp)
        libvlc_media_player_stop_async(d->mp);
}

void Player::seek(qint64 ms)
{
    if (!d->mp)
        return;
    ms = qMax<qint64>(0, d->length > 0 ? qMin(ms, d->length) : ms);
    libvlc_media_player_set_time(d->mp, toCore(ms), false);
    d->time = ms;
    emit timeChanged();
}

void Player::seekBy(qint64 deltaMs)
{
    seek(d->time + deltaMs);
}

void Player::setPosition(double position)
{
    if (!d->mp)
        return;
    position = qBound(0.0, position, 1.0);
    libvlc_media_player_set_position(d->mp, position, false);
    d->position = position;
    if (d->length > 0)
        d->time = qint64(position * d->length);
    emit timeChanged();
}

void Player::setChapter(int index)
{
    if (d->mp && index >= 0 && index < d->chapters.size())
        libvlc_media_player_set_chapter(d->mp, index);
}

void Player::nextChapter()
{
    if (d->mp)
        libvlc_media_player_next_chapter(d->mp);
}

void Player::previousChapter()
{
    if (d->mp)
        libvlc_media_player_previous_chapter(d->mp);
}

void Player::setVolume(int volume)
{
    volume = qBound(0, volume, 200);
    if (volume == d->volume)
        return;
    d->volume = volume;
    if (d->mp)
        libvlc_audio_set_volume(d->mp, volume);
    emit volumeChanged();
}

void Player::setMuted(bool muted)
{
    if (muted == d->muted)
        return;
    d->muted = muted;
    if (d->mp)
        libvlc_audio_set_mute(d->mp, muted ? 1 : 0);
    emit volumeChanged();
}

void Player::setRate(double rate)
{
    rate = qBound(0.25, rate, 4.0);
    if (d->mp)
        libvlc_media_player_set_rate(d->mp, float(rate));
    d->rate = rate;
    emit rateChanged();
}

void Player::selectTrack(int type, const QString &id)
{
    if (!d->mp)
        return;
    libvlc_media_track_t *track = libvlc_media_player_get_track_from_id(d->mp, id.toUtf8().constData());
    if (!track)
        return;
    if (track->i_type == toCoreTrackType(type))
        libvlc_media_player_select_track(d->mp, track);
    libvlc_media_track_release(track);
}

void Player::disableTrack(int type)
{
    if (d->mp)
        libvlc_media_player_unselect_track_type(d->mp, toCoreTrackType(type));
}

bool Player::addSubtitleFile(const QUrl &url)
{
    if (!d->mp || url.isEmpty())
        return false;
    return libvlc_media_player_add_slave(d->mp, libvlc_media_slave_type_subtitle,
                                         url.toString(QUrl::FullyEncoded).toUtf8().constData(),
                                         true) == 0;
}

void Player::setAudioDelay(qint64 ms)
{
    if (d->mp)
        libvlc_audio_set_delay(d->mp, toCore(ms));
    d->audioDelay = ms;
    emit delaysChanged();
}

void Player::setSubtitleDelay(qint64 ms)
{
    if (d->mp)
        libvlc_video_set_spu_delay(d->mp, toCore(ms));
    d->subtitleDelay = ms;
    emit delaysChanged();
}

void Player::setLoopA()
{
    d->loopA = d->time;
    d->loopB = -1;
    if (d->mp)
        libvlc_media_player_reset_abloop(d->mp);
    emit loopChanged();
}

void Player::setLoopB()
{
    if (d->loopA < 0 || d->time <= d->loopA)
        return;
    d->loopB = d->time;
    if (d->mp)
        libvlc_media_player_set_abloop_time(d->mp, toCore(d->loopA), toCore(d->loopB));
    emit loopChanged();
}

void Player::clearLoop()
{
    d->loopA = d->loopB = -1;
    if (d->mp)
        libvlc_media_player_reset_abloop(d->mp);
    emit loopChanged();
}

void Player::setBrightness(int v) { d->brightness = qBound(-100, v, 100); d->applyAdjust(); emit adjustChanged(); }
void Player::setContrast(int v) { d->contrast = qBound(-100, v, 100); d->applyAdjust(); emit adjustChanged(); }
void Player::setSaturation(int v) { d->saturation = qBound(-100, v, 100); d->applyAdjust(); emit adjustChanged(); }
void Player::setHue(int v) { d->hue = qBound(-180, v, 180); d->applyAdjust(); emit adjustChanged(); }
void Player::setGamma(int v) { d->gamma = qBound(-100, v, 100); d->applyAdjust(); emit adjustChanged(); }

void Player::resetPicture()
{
    d->brightness = d->contrast = d->saturation = d->hue = d->gamma = 0;
    d->applyAdjust();
    emit adjustChanged();
}

void Player::setAspectRatio(const QString &ratio)
{
    d->aspect = ratio;
    if (d->mp)
        libvlc_video_set_aspect_ratio(d->mp, ratio.isEmpty() ? nullptr : ratio.toUtf8().constData());
    emit geometryChanged();
}

void Player::setCropRatio(const QString &ratio)
{
    d->crop = ratio;
    unsigned num = 0, den = 0;
    const QStringList parts = ratio.split(QLatin1Char(':'));
    if (parts.size() == 2) {
        num = parts[0].toUInt();
        den = parts[1].toUInt();
    }
    if (d->mp)
        libvlc_video_set_crop_ratio(d->mp, num, den);
    emit geometryChanged();
}

void Player::setDeinterlace(int mode)
{
    d->deinterlace = qBound(-1, mode, 1);
    if (d->mp)
        libvlc_video_set_deinterlace(d->mp, d->deinterlace, nullptr);
    emit geometryChanged();
}

void Player::setEqualizerPreset(int index)
{
    if (index < 0 || unsigned(index) >= libvlc_audio_equalizer_get_preset_count())
        return;
    if (d->equalizer)
        libvlc_audio_equalizer_release(d->equalizer);
    d->equalizer = libvlc_audio_equalizer_new_from_preset(unsigned(index));
    d->eqPreset = index;
    d->eqEnabled = true;
    d->readEqualizer();
    d->applyEqualizer();
    emit equalizerChanged();
}

void Player::setEqualizerEnabled(bool enabled)
{
    d->eqEnabled = enabled;
    d->applyEqualizer();
    emit equalizerChanged();
}

void Player::setEqualizerPreamp(double db)
{
    libvlc_audio_equalizer_set_preamp(d->equalizer, float(qBound(-20.0, db, 20.0)));
    d->readEqualizer();
    d->applyEqualizer();
    emit equalizerChanged();
}

void Player::setEqualizerAmp(int band, double db)
{
    if (band < 0 || unsigned(band) >= libvlc_audio_equalizer_get_band_count())
        return;
    libvlc_audio_equalizer_set_amp_at_index(d->equalizer, float(qBound(-20.0, db, 20.0)), unsigned(band));
    d->eqPreset = -1;
    d->eqEnabled = true;
    d->readEqualizer();
    d->applyEqualizer();
    emit equalizerChanged();
}

void Player::resetEqualizer()
{
    if (d->equalizer)
        libvlc_audio_equalizer_release(d->equalizer);
    d->equalizer = libvlc_audio_equalizer_new();
    d->eqPreset = -1;
    d->eqEnabled = false;
    d->readEqualizer();
    d->applyEqualizer();
    emit equalizerChanged();
}

void Player::refreshAudioDevices()
{
    d->audioDevices.clear();
    if (!d->mp)
        return;
    libvlc_audio_output_device_t *list = libvlc_audio_output_device_enum(d->mp);
    for (auto *dev = list; dev; dev = dev->p_next) {
        QVariantMap m;
        m[QStringLiteral("id")] = QString::fromUtf8(dev->psz_device);
        m[QStringLiteral("name")] = QString::fromUtf8(dev->psz_description);
        d->audioDevices << m;
    }
    if (list)
        libvlc_audio_output_device_list_release(list);
    emit audioDevicesChanged();
}

void Player::setAudioDevice(const QString &id)
{
    if (d->mp)
        libvlc_audio_output_device_set(d->mp, id.toUtf8().constData());
}

QString Player::takeSnapshot(const QString &directory)
{
    if (!d->mp || !hasVideo())
        return {};
    QDir dir(directory);
    if (!dir.exists() && !dir.mkpath(QStringLiteral(".")))
        return {};
    const QString file = dir.filePath(QStringLiteral("Pulse %1.png")
                                          .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd hh.mm.ss"))));
    if (libvlc_video_take_snapshot(d->mp, 0, QDir::toNativeSeparators(file).toUtf8().constData(), 0, 0) != 0)
        return {};
    return file;
}

} // namespace pulse
