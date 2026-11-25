// Dota 2 runtime interfaces (resolved via CreateInterface)
#pragma once

namespace client_dll { // client.dll
    constexpr auto PanoramaUIClient001                      = 0x5D4E560; // client.dll + rva
    constexpr auto PlayButtonService001                     = 0x5D30BF0; // client.dll + rva
    constexpr auto DOTA_CLIENT_GCCLIENT                     = 0x6598870; // client.dll + rva
    constexpr auto LegacyGameUI001                          = 0x5D232E0; // client.dll + rva
    constexpr auto Source2ClientUI001                       = 0x5CE7668; // client.dll + rva
    constexpr auto Source2ClientPrediction001               = 0x63E7DF0; // client.dll + rva
    constexpr auto ClientToolsInfo_001                      = 0x5CC6C80; // client.dll + rva
    constexpr auto Source2Client002                         = 0x63DDE70; // client.dll + rva
    constexpr auto GameClientExports001                     = 0x5CC29C0; // client.dll + rva
    constexpr auto Source2ClientConfig001                   = 0x6373FF0; // client.dll + rva
}
namespace engine2_dll { // engine2.dll
    constexpr auto SimpleEngineLoopService_001              = 0x61DCA0; // engine2.dll + rva
    constexpr auto ClientServerEngineLoopService_001        = 0x9116B0; // engine2.dll + rva
    constexpr auto KeyValueCache001                         = 0x61DC20; // engine2.dll + rva
    constexpr auto HostStateMgr001                          = 0x61DB70; // engine2.dll + rva
    constexpr auto GameEventSystemServerV001                = 0x911340; // engine2.dll + rva
    constexpr auto GameEventSystemClientV001                = 0x911210; // engine2.dll + rva
    constexpr auto EngineServiceMgr001                      = 0x910F20; // engine2.dll + rva
    constexpr auto ClientServerSharedHandleSystem001        = 0x910C70; // engine2.dll + rva
    constexpr auto VProfService_001                         = 0x61DA20; // engine2.dll + rva
    constexpr auto ToolService_001                          = 0x61D9E0; // engine2.dll + rva
    constexpr auto StatsService_001                         = 0x9104B0; // engine2.dll + rva
    constexpr auto SplitScreenService_001                   = 0x61D8E0; // engine2.dll + rva
    constexpr auto SoundService_001                         = 0x90FFD0; // engine2.dll + rva
    constexpr auto ScreenshotService001                     = 0x90FE20; // engine2.dll + rva
    constexpr auto RenderService_001                        = 0x90FB50; // engine2.dll + rva
    constexpr auto NetworkService_001                       = 0x61D8A0; // engine2.dll + rva
    constexpr auto NetworkServerService_001                 = 0x90F8E0; // engine2.dll + rva
    constexpr auto NetworkP2PService_001                    = 0x90F730; // engine2.dll + rva
    constexpr auto NetworkClientService_001                 = 0x90F3F0; // engine2.dll + rva
    constexpr auto MapListService_001                       = 0x90F250; // engine2.dll + rva
    constexpr auto InputService_001                         = 0x8D03E0; // engine2.dll + rva
    constexpr auto GameUIService_001                        = 0x8D0100; // engine2.dll + rva
    constexpr auto GameResourceServiceServerV001            = 0x61D730; // engine2.dll + rva
    constexpr auto GameResourceServiceClientV001            = 0x61D6D0; // engine2.dll + rva
    constexpr auto BugBugService001                         = 0x61D690; // engine2.dll + rva
    constexpr auto BugService001                            = 0x8CFCB0; // engine2.dll + rva
    constexpr auto BenchmarkService001                      = 0x61D590; // engine2.dll + rva
    constexpr auto VENGINE_GAMEUIFUNCS_VERSION005           = 0x61B020; // engine2.dll + rva
    constexpr auto EngineGameUI001                          = 0x61AF90; // engine2.dll + rva
    constexpr auto INETSUPPORT_001                          = 0x616490; // engine2.dll + rva
    constexpr auto Source2EngineToServerStringTable001      = 0x61AA00; // engine2.dll + rva
    constexpr auto Source2EngineToServer001                 = 0x61A9D8; // engine2.dll + rva
    constexpr auto Source2EngineToClientStringTable001      = 0x61A960; // engine2.dll + rva
    constexpr auto Source2EngineToClient001                 = 0x61A900; // engine2.dll + rva
}
namespace server_dll { // server.dll
    constexpr auto NavGameTest001                           = 0x4CC89C0; // server.dll + rva
    constexpr auto Source2GameDirector001                   = 0x5346360; // server.dll + rva
    constexpr auto ServerToolsInfo_001                      = 0x4C580E8; // server.dll + rva
    constexpr auto Source2GameClients001                    = 0x4C56E80; // server.dll + rva
    constexpr auto Source2GameEntities001                   = 0x4C57890; // server.dll + rva
    constexpr auto Source2Server001                         = 0x4C576E0; // server.dll + rva
    constexpr auto Source2ServerConfig001                   = 0x5219038; // server.dll + rva
    constexpr auto EntitySubclassUtilsV001                  = 0x4A6A530; // server.dll + rva
}
namespace schemasystem_dll { // schemasystem.dll
    constexpr auto SchemaSystem_001                         = 0x76610; // schemasystem.dll + rva
}
namespace resourcesystem_dll { // resourcesystem.dll
    constexpr auto ResourceSystem013                        = 0x96FA0; // resourcesystem.dll + rva
}
namespace networksystem_dll { // networksystem.dll
    constexpr auto SerializedEntitiesVersion001             = 0x28D6A0; // networksystem.dll + rva
    constexpr auto NetworkSystemVersion001                  = 0x28D5C0; // networksystem.dll + rva
    constexpr auto NetworkMessagesVersion001                = 0x29FE60; // networksystem.dll + rva
    constexpr auto FlattenedSerializersVersion001           = 0x273BA0; // networksystem.dll + rva
}
namespace vphysics2_dll { // vphysics2.dll
    constexpr auto VPhysics2_Interface_001                  = 0x486550; // vphysics2.dll + rva
}
namespace particles_dll { // particles.dll
    constexpr auto ParticleSystemMgr003                     = 0x5E84F0; // particles.dll + rva
}
namespace soundsystem_dll { // soundsystem.dll
    constexpr auto SoundBugBugService001_Client             = 0x530FB0; // soundsystem.dll + rva
    constexpr auto SoundOpSystem001                         = 0x530E90; // soundsystem.dll + rva
    constexpr auto SoundOpSystemEdit001                     = 0x530DA0; // soundsystem.dll + rva
    // VMixEditTool001                          not in module image
    constexpr auto SoundSystem001                           = 0x646CD0; // soundsystem.dll + rva
}
namespace panorama_dll { // panorama.dll
    constexpr auto PanoramaUIEngine001                      = 0x5D1030; // panorama.dll + rva
}
