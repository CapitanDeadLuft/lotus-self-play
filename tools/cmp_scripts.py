b=r"D:\hake\lotus\backup_scripts_20261116_023749\Self Play.lua"
c=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\Self Play.lua"
for name,f in [("backup",b),("current",c)]:
    data=open(f, encoding='utf-8', errors='replace').read()
    print(name, "lines", data.count("\n"), "allylog", data.count("[SelfPlay ally]"), "departed", data.count("helpers.departed"), "state.allies", data.count("state.allies"))
    i=data.find("[SelfPlay ally]")
    if i>=0: print("   ctx:", data[max(0,i-300):i+200].replace("\n"," | ")[:500])
