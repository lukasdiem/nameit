# Import from a CSV or Excel file

Any student list in a spreadsheet works – for example a list exported from
WebUntis.

<div class="side" markdown>
<div markdown>

1. Copy the file to your phone (download, e-mail, cloud drive …).
2. In nameIT open **Import data → File**.
3. Pick the **school year**.
4. Tap **Choose file** and select the `.csv`, `.txt` or `.xlsx` file.
5. nameIT shows how many students it found, which classes, and the first
   few names. Check them and tap **Import**.

If the file has **no class column**, nameIT asks for the class name and puts
everyone into that class.

</div>

![File import tab](../../assets/screenshots/import-file.png){ .shot }
</div>

## What the file should look like

The first row holds the column names. nameIT recognises these headers –
upper/lower case doesn't matter:

| Column | Recognised headers |
|---|---|
| First name | `Vorname`, `First name`, `Firstname`, `Forename`, `Given name` |
| Last name | `Nachname`, `Familienname`, `Last name`, `Lastname`, `Surname`, `Family name`, `longName` |
| Class *(optional)* | `Klasse`, `Klassen`, `Klassenname`, `Class` |
| Full name | `Name`, `Schüler`, `Schueler`, `Schüler*in`, `Student` |

Other columns are ignored.

```text title="demo-classes.csv"
Klasse;Nachname;Vorname;Foto
3B;Gruber;Lena;lena-gruber.jpg
3B;Huber;Felix;felix-huber.jpg
4A;Mayr;Laura;laura-mayr.jpg
```

### Details the importer takes care of

* **Separators:** semicolon, comma or tab – detected from the first line.
* **Encoding:** UTF-8, and Latin-1 files from Excel on German Windows, so
  *Müller* and *Jürgen* come out right.
* **A title line** above the header (as in some exports) is skipped.
* **Only a full-name column:** `Name` alone is split at the last space
  (`Anna Maria Berger` → first name *Anna Maria*, last name *Berger*).
* **`Name` + `Vorname`:** `Name` is taken as the last name.
* **No header at all:** columns are read as *last name, first name, class*.
* Values like `007` stay text – no number conversion.
* Quoted values with commas (`"Huber, Jr."`) work.
* Excel files: the first sheet is read.

!!! tip "Several classes in one file"
    With a class column, one file can fill several classes at once – the demo
    file creates **3B** and **4A**.
