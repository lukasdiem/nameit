# Try it with the demo class

All screenshots in this documentation use a **made-up class**: 28 comic
students in two classes. You can import the same class into the app to try
everything without real student data – handy for showing nameIT to
colleagues, too.

<div class="avatars" markdown>
![Lena Gruber](../demo/avatars/lena-gruber.jpg){ title="Lena Gruber" }
![Felix Huber](../demo/avatars/felix-huber.jpg){ title="Felix Huber" }
![Anna Berger](../demo/avatars/anna-berger.jpg){ title="Anna Berger" }
![Jonas Wagner](../demo/avatars/jonas-wagner.jpg){ title="Jonas Wagner" }
![Sophie Pichler](../demo/avatars/sophie-pichler.jpg){ title="Sophie Pichler" }
![Elias Moser](../demo/avatars/elias-moser.jpg){ title="Elias Moser" }
![Emma Steiner](../demo/avatars/emma-steiner.jpg){ title="Emma Steiner" }
![Paul Hofer](../demo/avatars/paul-hofer.jpg){ title="Paul Hofer" }
![Zeynep Yılmaz](../demo/avatars/zeynep-yilmaz.jpg){ title="Zeynep Yılmaz" }
![David Bauer](../demo/avatars/david-bauer.jpg){ title="David Bauer" }
![Hannah Fuchs](../demo/avatars/hannah-fuchs.jpg){ title="Hannah Fuchs" }
![Luca Eder](../demo/avatars/luca-eder.jpg){ title="Luca Eder" }
![Marie Schwarz](../demo/avatars/marie-schwarz.jpg){ title="Marie Schwarz" }
![Noah Brunner](../demo/avatars/noah-brunner.jpg){ title="Noah Brunner" }
![Amara Okafor](../demo/avatars/amara-okafor.jpg){ title="Amara Okafor" }
![Tobias Winkler](../demo/avatars/tobias-winkler.jpg){ title="Tobias Winkler" }
![Clara Haas](../demo/avatars/clara-haas.jpg){ title="Clara Haas" }
![Nikola Petrović](../demo/avatars/nikola-petrovic.jpg){ title="Nikola Petrović" }
</div>

<div class="avatars" markdown>
![Laura Mayr](../demo/avatars/laura-mayr.jpg){ title="Laura Mayr" }
![Ben Aigner](../demo/avatars/ben-aigner.jpg){ title="Ben Aigner" }
![Mia Leitner](../demo/avatars/mia-leitner.jpg){ title="Mia Leitner" }
![Amir Kaya](../demo/avatars/amir-kaya.jpg){ title="Amir Kaya" }
![Valentina Rossi](../demo/avatars/valentina-rossi.jpg){ title="Valentina Rossi" }
![Jakob Lehner](../demo/avatars/jakob-lehner.jpg){ title="Jakob Lehner" }
![Lea Wimmer](../demo/avatars/lea-wimmer.jpg){ title="Lea Wimmer" }
![Matteo Fischer](../demo/avatars/matteo-fischer.jpg){ title="Matteo Fischer" }
![Ida Schmid](../demo/avatars/ida-schmid.jpg){ title="Ida Schmid" }
![Simon Egger](../demo/avatars/simon-egger.jpg){ title="Simon Egger" }
</div>

## Downloads

| File | What it is |
|---|---|
| [:material-file-delimited: demo-classes.csv](../demo/demo-classes.csv) | Class list: classes **3B** (18 students) and **4A** (10) |
| [:material-folder-zip: avatars.zip](../demo/avatars.zip) | All 28 avatars as JPG, named `firstname-lastname.jpg` |

## Import it on your phone

1. Download both files on your phone and unzip `avatars.zip`
   (most file managers do this with a tap). Keep the pictures in your
   gallery or a folder you can find.
2. In nameIT: **+ → Import data → File**, pick the school year, choose
   `demo-classes.csv` and tap **Import**. Classes **3B** and **4A** appear.
3. Open **3B**, tap a student, tap **Gallery** and pick the picture with
   their name. Repeat for each student.

    The `Foto` column in the CSV says which picture belongs to whom. nameIT
    ignores that column – it is only there for you.

4. Tap **Play**. With four or more photos every game is unlocked.

!!! tip "Just a few photos"
    You don't need all 28. Give photos to five or six students of 3B and all
    games work.

!!! info "No bulk photo import (yet)"
    Photos are added one student at a time. That's why the documentation
    screenshots aren't made on a phone – they are rendered automatically from
    the same files, see [Docs & screenshots](../developers/docs-and-screenshots.md).

## Where it comes from

The names are invented and common in Austria. The avatars are drawn by a
small script, [`tool/demo/generate_demo.py`](https://github.com/lukasdiem/nameit/blob/main/tool/demo/generate_demo.py),
from random combinations of hair, eyes, mouth, glasses and colours – no
photos or real people involved.
