find_package(Qt6 REQUIRED COMPONENTS Test)

add_executable(tst_engine tst_engine.cpp)
target_link_libraries(tst_engine PRIVATE pulse_engine pulse_app Qt6::Test)
add_test(NAME engine COMMAND tst_engine)
set_tests_properties(engine PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

add_executable(tst_queue tst_queue.cpp)
target_link_libraries(tst_queue PRIVATE pulse_app Qt6::Test)
add_test(NAME queue COMMAND tst_queue)
set_tests_properties(queue PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
