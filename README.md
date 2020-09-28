# Steam Guide Uploader

This is a program which allows uploading a [Steam guide](https://steamcommunity.com/guides) from text files on the command line.

Useful for anyone who would prefer to use their favorite text editor or other tools for authoring their guides.

## Usage

### Building

[Get D](https://dlang.org/download.html) and run `dub build` in the program directory to build the `upload` program.

### Uploader Setup

You must first export your cookies to a text file to allow the program to upload the guide under your account. To do so:

1. Visit http://steamcommunity.com/ in your web browser of choice.
2. Ensure that you are logged in. If you aren't, log in now.
3. Open the Developer Console or equivalent (usually done by pressing <kbd>F12</kbd>).
4. Open the "Network" tab in the Developer Console (or equivalent).
5. Reload the page.
6. Click on the very first request added to the request list, which should be for the http://steamcommunity.com/ page.
7. Find the "Request headers" pane in the Developer Console or equivalent.
8. Find the "Cookie" header within.
9. Copy the value of the cookie header.
10. Navigate to your user app settings directory:
    - Windows: `%USERPROFILE%\AppData`
    - POSIX (Linux/Mac): `$XDG_CONFIG_HOME` or `~/.config`
11. Create the directory `cookies.
12. Create the text file `steamcommunity.com` (no additional extension).
13. Paste the value of the cookie header.

### Guide Setup

1. Create the guide on Steam as usual - fill in the name, description, categories, and branding image.
2. Find your guide ID in the URL bar.
   E.g. for http://steamcommunity.com/sharedfiles/manageguide/?id=1234567890, the guide ID is 1234567890.
3. Create a new directory for your guide.
4. In the directory, create a text file, called `guideid.txt`, which contains the ID (and nothing else).

Although you can use this software with existing guides, note that it will irreversibly **overwrite** the entire guide while uploading.

The same warning applies if you intend to make edits through Steam's web interface.

### Authoring Guides

In your guide directory, create one text file per section, with the extension `.steamguide`.

The format is as follows:

- The first line is the section title.
- The second line should be blank.
- The third and following lines are the section body.

The section ordering is defined by the lexicographical ordering of the `.steamguide` file names, therefore the author recommends using filenames such as `00-introduction.steamguide`, `01-how-to-use-this-guide.steamguide`, `02-chapter-one.steamguide` etc.

The author recommends placing the `.steamguide` files under version control (i.e. Git), and publishing it on GitHub, so that editing history is recorded and contributions to the guide can be easily accepted using GitHub pull requests.

Aside from what is described here, the guide text is uploaded as-is, and is formatted according to [Steam's guide/comment formatting syntax](http://steamcommunity.com/comment/Guide/formattinghelp).

Compile and run the `upload` program to overwrite the online version of the guide with that in your `.steamguide` files.

#### Sections

The program will attempt to preserve section IDs (so as to not break links to individual guide sections). This is done by maintaining a mapping from each `.steamguide` file name to a Steam subsection ID in the file `sections.txt`. If you decide to rename some sections' `.steamguide` files, you may want to update the file names in `sections.txt` as well.

An additional syntax is provided for linking to sections: `[section-link=SECTION-NAME-OR-ID]LINK-TEXT[/section-link]`. The `[section-link]` tag allows creating a link to a specific section within the same guide, and will be rewritten to an `[url]` tag with an anchor to the corresponding section. `SECTION-NAME-OR-ID` can be either the file name of a `.steamguide` section file (extension is optional), or the numeric section ID.

#### Images

If you create a directory called `images` in your guide directory, the program will also upload any image files placed there.

You can then reference them in your guide using the usual `[previewimg]` and `[previewicon]` tags, however, instead of the numeric ID, you can specify an image file name. For example: `[previewicon=smiley.png;sizeOriginal,inline][/previewicon]`
