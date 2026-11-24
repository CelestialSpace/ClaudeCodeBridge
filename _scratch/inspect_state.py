import sqlite3, sys
p = r"C:\Users\zhut\AppData\Local\Temp\state_copy2.vscdb"
db = sqlite3.connect(p)
rows = db.execute("select key, length(value) from ItemTable where key like '%Auth%' or key like '%auth%' or key like '%Token%' or key like '%token%' order by key").fetchall()
for k, n in rows:
    print(k, n)
print("---- itemtable total:", db.execute("select count(*) from ItemTable").fetchone()[0])
