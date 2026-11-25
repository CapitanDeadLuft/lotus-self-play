// Dota 2 engine globals via signature scan
#pragma once
#include <cstdint>

namespace engine {
    constexpr auto dwEntityList             = 0x6649410; // client.dll
    constexpr auto dwViewMatrix             = 0x0; // FAIL: sig not found
    constexpr auto dwLocalPlayerController  = 0x63E30A0; // client.dll
}
