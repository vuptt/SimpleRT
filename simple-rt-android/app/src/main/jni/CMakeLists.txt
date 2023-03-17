cmake_minimum_required(VERSION 3.4.1)

add_library(
        simplertjni
        SHARED
        tetherservice.c
)

find_library(
        log-lib
        log
)

target_link_libraries(
        simplertjni
        ${log-lib}
)