# gitback

Backups the **entirety** (code, wiki, issues) of a GitHub repo to the directory of your choosing  (might I suggest your Dropbox directory?).

## Usage

    ./gitback username/repo destination/directory

If it's a private repo:

    ./gitback --username=username --password=password username/repo destination/directory

That's it.

## Dependencies

- octokit
- nokogiri
