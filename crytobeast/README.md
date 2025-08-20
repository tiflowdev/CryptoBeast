# 🐉 Battle Creatures - NFT Battle Game (Clarity Smart Contract)

A simplified **Axie Infinity–style turn-based NFT battle game** built on the Stacks blockchain.  
Players can mint unique creatures, challenge others to battles, and track their battle history.

---

## ✨ Features

- **Creature Minting**:  
  - Mint unique NFT creatures with base stats based on type (Fire, Water, Earth, Default).  
  - Costs `1 STX` (configurable).  

- **Battle System**:  
  - Turn-based battles between two players.  
  - Supports `attack`, `defend`, and `special` moves.  
  - Stats and types influence the outcome.  
  - Experience points gained after each battle.  

- **Battle Tracking**:  
  - Maintains win/loss/totals per player.  
  - Records health, turn order, and outcome of each battle.  

- **Ownership**:  
  - Creatures are linked to players.  
  - Players can view all their owned creatures.  

- **Admin Controls**:  
  - Contract owner can update mint price.  

---

## 📦 Data Structures

### Maps

- **`creatures`**: Stores NFT creature data.  
- **`creature-owners`**: Maps player → list of creature IDs.  
- **`battles`**: Stores ongoing and finished battle details.  
- **`battle-history`**: Stores aggregated stats per player.  

### Creature Schema
```clarity
{
  owner: principal,
  name: (string-ascii 32),
  creature-type: (string-ascii 16),
  health: uint,
  attack: uint,
  defense: uint,
  speed: uint,
  level: uint,
  experience: uint,
  in-battle: bool
}
