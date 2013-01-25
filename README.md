# Pickbox
## Introduction
Pickbox is a client-server suite that provides directory syncing across computers. It utilizes convergent encryption to achieve security and file de-duplication.

## Implementation
### File Encryption
During syncing, Pickbox will use AES-256-CBC algorithm to encrypt each file. The SHA-256 hash of the content of each file will be used as encryption key. Such method can eliminate file duplications on server since identical files would share exactly same cipher. Then the SHA-256 hash will be encrypted in AES-256-CBC while using user's password as encryption key and stored locally.

The encrypted cipher would be uploaded to server and stored as individual file while using another SHA-256 hash of cipher itself as filename.