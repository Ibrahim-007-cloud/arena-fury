# Firestore & Storage data model

```
users/{uid}                                  ← private profile + aggregate record
  displayName: string
  email: string | null
  isGuest: bool
  wins: int        (FieldValue.increment)
  losses: int
  draws: int
  lastSeenAt / updatedAt: timestamp

users/{uid}/fighters/{fighterId}             ← custom fighters (max 2; 4 built-ins live in code)
  name: string (1..16)
  costumeId: 'gi' | 'street' | 'armor' | 'ninja'
  bodyType: 'slim' | 'standard' | 'heavy'
  primaryColor: int (ARGB32)
  secondaryColor: int
  skinColor: int
  hairColor: int
  movesetId: 'striker' | 'brawler' | 'ninja' | 'tempest'
  stats: { power: 1..5, speed: 1..5, defense: 1..5 }   (sum ≤ 10)
  faceImagePath: string | null   e.g. "users/{uid}/faces/{fighterId}.png"
  faceImageUrl: string | null    download URL (handy for the console / web)
  createdAt: timestamp
  updatedAt: timestamp

users/{uid}/matches/{matchId}                ← append-only match history
  mode: 'arcade'
  playerFighterId / playerFighterName
  opponentFighterId / opponentFighterName
  stageId: string
  outcome: 'win' | 'loss' | 'draw'
  roundsWon: int, roundsLost: int
  difficulty: 'easy' | 'normal' | 'hard'
  durationSeconds: int
  playedAt: serverTimestamp

leaderboard/{uid}                            ← public, one doc per player
  displayName, wins, losses, draws, updatedAt
```

**Firebase Storage:** `users/{uid}/faces/{fighterId}.png` — 512×512 PNG produced by the
circular cropper (< 2 MB, enforced by `storage.rules`).

### Write paths
| Action | Writes |
|---|---|
| Save fighter (Studio) | upload PNG → Storage, then `set` `users/{uid}/fighters/{id}` |
| Finish Arcade match | one **batch**: add `matches/{auto}`, `increment` counters on `users/{uid}` **and** `leaderboard/{uid}` |
| Login | `merge` displayName/email into `users/{uid}` |

### Reads
- Roster: `users/{uid}/fighters` ordered by `createdAt` (live `snapshots()`).
- Leaderboard: `leaderboard` ordered by `wins desc`, `limit(25)`.
- My record: `users/{uid}` doc + `users/{uid}/matches` ordered by `playedAt desc`, `limit(10)`.

All queries use single-field indexes, so no composite indexes need to be created.
