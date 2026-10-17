#include "preferences.hpp"

#include <QMetaProperty>
#include <QSettings>

namespace pulse {

Preferences::Preferences(QObject *parent)
    : QObject(parent)
{
    QSettings s;
    const int stored = s.value(QStringLiteral("prefs/schema"), 0).toInt();
    if (stored != kSchemaVersion) {
        migrate(stored);
        s.setValue(QStringLiteral("prefs/schema"), kSchemaVersion);
    }
    load();
}

void Preferences::store(const char *key, const QVariant &value)
{
    QSettings().setValue(QStringLiteral("prefs/") + QLatin1String(key), value);
}

void Preferences::load()
{
    QSettings s;
    const QMetaObject *mo = metaObject();
    for (int i = mo->propertyOffset(); i < mo->propertyCount(); ++i) {
        const QMetaProperty p = mo->property(i);
        if (!p.isWritable())
            continue;
        const QString key = QStringLiteral("prefs/") + QLatin1String(p.name());
        if (s.contains(key))
            p.write(this, s.value(key));
    }
}

void Preferences::migrate(int from)
{
    // Schema 0 -> 1: first versioned release, nothing to convert yet.
    // Later schema bumps transform stored keys here, oldest first.
    Q_UNUSED(from);
}

void Preferences::resetAll()
{
    QSettings().remove(QStringLiteral("prefs"));
    Preferences defaults;
    const QMetaObject *mo = metaObject();
    for (int i = mo->propertyOffset(); i < mo->propertyCount(); ++i) {
        const QMetaProperty p = mo->property(i);
        if (p.isWritable())
            p.write(this, p.read(&defaults));
    }
    QSettings().setValue(QStringLiteral("prefs/schema"), kSchemaVersion);
}

} // namespace pulse
