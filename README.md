# Folder-backup-to-smb
  -  Zalohuje priecinok na lokalnu siet pomocou 7z
  -  Kontroluje pocet zaloh a maze viac ako 10 zaloh
  -  7z musi byt nainstalovany na predvolenej ceste, (C:\Program Files\7-Zip)
  -  Spustat ako Administrator


Uprav v skripte:
-  [string]$SourceFolder = "CESTA K ZALOHOVANEMU PRIECINKU",  - Priecinok ktory sa ide zalohovat
-  [string]$SevenZipPath = "C:\Program Files\7-Zip\7z.exe",   - Zmen iba ak 7z je naistalovany inde ako na predvolenej ceste
-  [string]$SMBPath = "\\CESTA NA ULOZENIE NA SIET SMB",      - Cielova cesta na sietovom disku
-  [string]$ArchivePrefix = "NASTAV NAZOV ZALOHY",            - Vysledny nazov archivu, sklada sa z prefixu ktory nastavis a datum + cas spustenia skriptu
-  [int]$RetentionCount = 10  # predvolený počet archívov na zachovanie
