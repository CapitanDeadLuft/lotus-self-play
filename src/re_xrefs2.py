import os, re
from capstone import Cs, CS_ARCH_X86, CS_MODE_64
from capstone.x86 import X86_OP_MEM, X86_REG_RIP
from collections import Counter

REG_DIR = r"D:\hake\lotus\dumps\ureg"
NAMES = ["GetAutoCastState","GetChannelStartTime","GetOwner","IsAttributes","IsOwnersManaEnough",
 "GetDisplayNameByUnitName","PlayVol","GetAbsOriginXYZ","IsAbility","ChatMessage","GetDOTATime",
 "GetGameEndTime","GetLobbyID","GetStrengthTotal","InRadius","GetAttackTime","GetBaseSpellAmp",
 "GetCastRangeBonus","GetMagicalArmorValue","GetPhysicalArmorValue","GetSpellAmplification",
 "IsBuilding","IsPositionInRange","GetAbsOrigin","PrepareUnitOrders","GetAttackRange","IsDormant","GetTeamData"]

files=[]
for fn in os.listdir(REG_DIR):
    m=re.match(r"^ureg_([0-9A-F]+)\.bin$",fn)
    if not m: continue
    base=int(m.group(1),16); path=os.path.join(REG_DIR,fn)
    size=os.path.getsize(path); files.append((base,size,path))
files.sort()
print("regions",len(files),"total MB",round(sum(s for _,s,_ in files)/1e6,1),flush=True)
sizes=Counter(s>>20 for _,s,_ in files)
print("size histogram(MB):",dict(list(sizes.items())[:10]),flush=True)

# resolve name addresses
name_addr={}
for base,size,path in files:
    if len(name_addr)==len(NAMES): break
    if size < 64: continue
    data=open(path,'rb').read()
    for n in NAMES:
        if n in name_addr: continue
        i=data.find(n.encode()+b"\x00")
        if i>=0: name_addr[n]=base+i
print("names resolved",len(name_addr),flush=True)
targets={}
for n,a in name_addr.items():
    for d,l in ((0,""),(-8,"-8"),(-16,"-16"),(-24,"-24")):
        targets[a+d]=n+l

md=Cs(CS_ARCH_X86,CS_MODE_64); md.detail=True
hits=[]; scanned=0
for base,size,path in files:
    if size < 0x8000: continue
    data=open(path,'rb').read()
    scanned += len(data)
    try:
        for ins in md.disasm(data, base):
            for op in ins.operands:
                if op.type==X86_OP_MEM and op.mem.base==X86_REG_RIP:
                    tgt=ins.address+ins.size+op.mem.disp
                    if tgt in targets:
                        hits.append((ins.address,ins.mnemonic,ins.op_str,targets[tgt],tgt))
                        if len(hits)<=40:
                            print(f"XREF {ins.address:X} {ins.mnemonic} {ins.op_str} -> {targets[tgt]}",flush=True)
    except Exception:
        pass
print("scanned MB",round(scanned/1e6,1),"hits",len(hits),flush=True)
with open(os.path.join(REG_DIR,"xrefs2.txt"),"w",encoding="utf-8") as f:
    for a,m,o,t,tg in hits: f.write(f"{a:X}\t{m}\t{o}\t{t}\t{tg:X}\n")
print("saved xrefs2.txt",flush=True)
