import os
p = r"C:\Users\zhut\AppData\Local\Temp\state_copy2.vscdb"
print("exists:", os.path.exists(p))
print("size:", os.path.getsize(p))
with open(p, 'rb') as f:
    data = f.read(16)
print("first16:", data[:16])
print("sqlite header ok:", data[:16] == b'SQLite format 3\x00')
