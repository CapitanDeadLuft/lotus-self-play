// lua_bridge.h — registers Self Play's Lua API (39 namespaces / 223 fns, see api_surface.txt / api_by_ns.json)
// into LuaJIT, backed by our own reader (rd::Reader). Our own loader => no Themida/VM-check/subscription.
#pragma once
#include <lua.hpp>
#include "reader.h"

namespace bridge {

// Register all namespaces as Lua globals (Entity, NPC, Hero, Player, Heroes, GridNav, GameRules, Render, Menu, ...).
void RegisterAll(lua_State* L, rd::Reader* r);

// Per-namespace binders (each implements the fns listed in api_by_ns.json):
void BindEntity(lua_State*, rd::Reader*);     // GetAbsOrigin/GetHealth/GetTeamNum/IsAlive/IsDormant/...
void BindNPC(lua_State*, rd::Reader*);        // GetUnitName/GetAttackRange/IsHero/IsCreep/MoveTo/HasModifier/...
void BindAbility(lua_State*, rd::Reader*);    // GetLevel/GetCooldown/IsReady/CastNoTarget/CastPosition/...
void BindItem(lua_State*, rd::Reader*);
void BindHero(lua_State*, rd::Reader*);       // GetPlayerID/GetStrength/GetRespawnTime/...
void BindHeroes(lua_State*, rd::Reader*);     // GetAll/GetLocal
void BindPlayer(lua_State*, rd::Reader*);     // PrepareUnitOrders/AttackTarget/HoldPosition/GetTotalGold/...
void BindPlayers(lua_State*, rd::Reader*);
void BindGameRules(lua_State*, rd::Reader*);  // GetGameTime/GetGameState/IsPaused/...
void BindGridNav(lua_State*, rd::Reader*);    // IsTraversable/BuildPath/CreateNpcMap/...
void BindWorld(lua_State*, rd::Reader*);      // GetGroundZ
void BindRender(lua_State*, rd::Reader*);     // Text/Line/Circle/WorldToScreen/LoadFont/... (D3D hook)
void BindMenu(lua_State*, rd::Reader*);       // Create/Find (ClickGUI)
void BindConfig(lua_State*, rd::Reader*);     // Read/Write Int/Float/String
void BindEngine(lua_State*, rd::Reader*);     // IsInGame/IsInLobby/ExecuteCommand/AcceptMatch/...
void BindGC(lua_State*, rd::Reader*);         // GetSteamID/SendMessage (GC protobuf)
void BindNetChannel(lua_State*, rd::Reader*); // GetAvgLatency/SendNetMessage
void BindFogOfWar(lua_State*, rd::Reader*);
void BindModifier(lua_State*, rd::Reader*);
void BindTrees(lua_State*, rd::Reader*);
void BindRunes(lua_State*, rd::Reader*);
void BindCouriers(lua_State*, rd::Reader*);
void BindPhysicalItems(lua_State*, rd::Reader*);
void BindTower(lua_State*, rd::Reader*);
void BindLog(lua_State*, rd::Reader*);
void BindInput(lua_State*, rd::Reader*);
void BindHumanizer(lua_State*, rd::Reader*);
void BindPanorama(lua_State*, rd::Reader*);
void BindHTTP(lua_State*, rd::Reader*);
void BindXHelpers(lua_State*, rd::Reader*);
// ... remaining namespaces per api_by_ns.json

} // namespace bridge