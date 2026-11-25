// reader.h — prototype of our own Dota 2 reader, replicating the Lotus SDK schema method.
// Patch-resilient: offsets resolved at runtime via the game's SchemaSystem (not hardcoded).
// Reference: PaskedaDota2SDK.dll strings (SchemaSystem_001, Source2EngineToClient001, Schema::OffsetOf).
#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include <unordered_map>

namespace rd {

// --- Source2 interface acquisition (CreateInterface from engine2/client/schemasystem) ---
using CreateInterfaceFn = void* (*)(const char* name, int* ret);
void* GetInterface(const char* module, const char* iface);   // e.g. ("schemasystem.dll","SchemaSystem_001"), ("client.dll","Source2EngineToClient001")

// --- Schema system: resolve class/field offsets at runtime ---
struct Schema {
  void* system = nullptr;                 // SchemaSystem_001
  void* clientScope = nullptr;            // client.dll type scope
  bool Init();
  // Schema::OffsetOf("C_DOTA_BaseNPC","m_iHealth") -> offset
  int OffsetOf(const char* cls, const char* field);
  int cached(const char* cls, const char* field);
  std::unordered_map<std::string,int> cache;
};

// --- Entity model (fields from SDK strings) ---
struct Vec3 { float x,y,z; };
struct Entity {
  uint32_t index; uint32_t handle;
  std::string className;                  // npc_dota_hero_* / npc_dota_creep_* ...
  int team; int health; int maxHealth; int lifeState;
  Vec3 origin; bool dormant;
  // NPC
  int moveSpeed, damageMin, damageMax, attackRange; bool isIllusion, isNeutral, isRanged;
  // Hero
  int heroID, playerID;
};

struct Reader {
  Schema schema;
  void* engineToClient = nullptr;         // Source2EngineToClient001
  bool Init();
  std::vector<Entity> Snapshot();         // world unit snapshot (like SDK "World unit snapshot")
  Entity LocalHero();
  // gamerules
  int GameState(); float GameTime(); float GameStartTime(); bool Paused();
  // combatlog / stringtables hooks (last_hit, entity_killed, entity_hurt)
};

} // namespace rd