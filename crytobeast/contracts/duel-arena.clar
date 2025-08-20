;; Battle Creatures - NFT Battle Game Contract
;; Simplified Axie Infinity-style game with turn-based battles

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-battle (err u103))
(define-constant err-creature-busy (err u104))
(define-constant err-insufficient-funds (err u105))

;; Data Variables
(define-data-var next-creature-id uint u1)
(define-data-var next-battle-id uint u1)
(define-data-var mint-price uint u1000000) ;; 1 STX

;; Data Maps
(define-map creatures 
  uint 
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
)

(define-map creature-owners 
  principal 
  (list 50 uint)
)

(define-map battles 
  uint 
  {
    player1: principal,
    player2: principal,
    creature1-id: uint,
    creature2-id: uint,
    winner: (optional principal),
    turn: uint,
    status: (string-ascii 16),
    player1-health: uint,
    player2-health: uint,
    block-height: uint
  }
)

(define-map battle-history 
  principal 
  {
    wins: uint,
    losses: uint,
    total-battles: uint
  }
)

;; Creature minting function
(define-public (mint-creature (name (string-ascii 32)) (creature-type (string-ascii 16)))
  (let 
    (
      (creature-id (var-get next-creature-id))
      (base-stats (get-base-stats-by-type creature-type))
    )
    (try! (stx-transfer? (var-get mint-price) tx-sender contract-owner))
    (map-set creatures creature-id
      {
        owner: tx-sender,
        name: name,
        creature-type: creature-type,
        health: (get health base-stats),
        attack: (get attack base-stats),
        defense: (get defense base-stats),
        speed: (get speed base-stats),
        level: u1,
        experience: u0,
        in-battle: false
      }
    )
    (map-set creature-owners tx-sender
      (unwrap! (as-max-len? 
        (append 
          (default-to (list) (map-get? creature-owners tx-sender)) 
          creature-id
        ) u50) (err u106))
    )
    (var-set next-creature-id (+ creature-id u1))
    (ok creature-id)
  )
)

;; Get base stats by creature type
(define-read-only (get-base-stats-by-type (creature-type (string-ascii 16)))
  (if (is-eq creature-type "fire")
    {health: u120, attack: u25, defense: u15, speed: u20}
    (if (is-eq creature-type "water")
      {health: u100, attack: u20, defense: u20, speed: u25}
      (if (is-eq creature-type "earth")
        {health: u140, attack: u20, defense: u25, speed: u15}
        {health: u110, attack: u22, defense: u18, speed: u22}
      )
    )
  )
)

;; Start a battle
(define-public (challenge-battle (creature-id uint) (opponent principal) (opponent-creature-id uint))
  (let 
    (
      (battle-id (var-get next-battle-id))
      (my-creature (unwrap! (map-get? creatures creature-id) err-not-found))
      (opponent-creature (unwrap! (map-get? creatures opponent-creature-id) err-not-found))
    )
    (asserts! (is-eq (get owner my-creature) tx-sender) err-unauthorized)
    (asserts! (is-eq (get owner opponent-creature) opponent) err-unauthorized)
    (asserts! (is-eq (get in-battle my-creature) false) err-creature-busy)
    (asserts! (is-eq (get in-battle opponent-creature) false) err-creature-busy)
    
    ;; Mark creatures as in battle
    (map-set creatures creature-id
      (merge my-creature {in-battle: true})
    )
    (map-set creatures opponent-creature-id
      (merge opponent-creature {in-battle: true})
    )
    
    ;; Create battle
    (map-set battles battle-id
      {
        player1: tx-sender,
        player2: opponent,
        creature1-id: creature-id,
        creature2-id: opponent-creature-id,
        winner: none,
        turn: u1,
        status: "active",
        player1-health: (get health my-creature),
        player2-health: (get health opponent-creature),
        block-height: block-height
      }
    )
    
    (var-set next-battle-id (+ battle-id u1))
    (ok battle-id)
  )
)

;; Execute battle turn
(define-public (battle-turn (battle-id uint) (action (string-ascii 16)))
  (let 
    (
      (battle (unwrap! (map-get? battles battle-id) err-not-found))
      (current-player (if (is-eq (mod (get turn battle) u2) u1) 
                       (get player1 battle) 
                       (get player2 battle)))
    )
    (asserts! (is-eq tx-sender current-player) err-unauthorized)
    (asserts! (is-eq (get status battle) "active") err-invalid-battle)
    
    (if (is-eq action "attack")
      (execute-attack battle-id)
      (if (is-eq action "defend")
        (execute-defend battle-id)
        (execute-special battle-id)
      )
    )
  )
)

;; Execute attack action
(define-private (execute-attack (battle-id uint))
  (let 
    (
      (battle (unwrap! (map-get? battles battle-id) err-not-found))
      (is-player1-turn (is-eq (mod (get turn battle) u2) u1))
      (attacker-creature-id (if is-player1-turn 
                            (get creature1-id battle) 
                            (get creature2-id battle)))
      (attacker-creature (unwrap! (map-get? creatures attacker-creature-id) err-not-found))
      (damage (calculate-damage attacker-creature u0))
      (new-health (if is-player1-turn
                    (if (> (get player2-health battle) damage)
                      (- (get player2-health battle) damage)
                      u0)
                    (if (> (get player1-health battle) damage)
                      (- (get player1-health battle) damage)
                      u0)))
    )
    (map-set battles battle-id
      (merge battle 
        {
          turn: (+ (get turn battle) u1),
          player1-health: (if is-player1-turn (get player1-health battle) new-health),
          player2-health: (if is-player1-turn new-health (get player2-health battle)),
          winner: (if (is-eq new-health u0)
                    (some (if is-player1-turn (get player1 battle) (get player2 battle)))
                    none),
          status: (if (is-eq new-health u0) "finished" "active")
        }
      )
    )
    
    ;; Update battle history if battle finished
    (if (is-eq new-health u0)
      (begin
        (update-battle-stats (get player1 battle) (get player2 battle) is-player1-turn)
        (end-battle battle-id)
      )
      (ok true)
    )
  )
)

;; Execute defend action
(define-private (execute-defend (battle-id uint))
  (let 
    (
      (battle (unwrap! (map-get? battles battle-id) err-not-found))
    )
    (map-set battles battle-id
      (merge battle {turn: (+ (get turn battle) u1)})
    )
    (ok true)
  )
)

;; Execute special action
(define-private (execute-special (battle-id uint))
  (let 
    (
      (battle (unwrap! (map-get? battles battle-id) err-not-found))
      (is-player1-turn (is-eq (mod (get turn battle) u2) u1))
      (attacker-creature-id (if is-player1-turn 
                            (get creature1-id battle) 
                            (get creature2-id battle)))
      (attacker-creature (unwrap! (map-get? creatures attacker-creature-id) err-not-found))
      (special-damage (calculate-damage attacker-creature u10))
      (new-health (if is-player1-turn
                    (if (> (get player2-health battle) special-damage)
                      (- (get player2-health battle) special-damage)
                      u0)
                    (if (> (get player1-health battle) special-damage)
                      (- (get player1-health battle) special-damage)
                      u0)))
    )
    (map-set battles battle-id
      (merge battle 
        {
          turn: (+ (get turn battle) u1),
          player1-health: (if is-player1-turn (get player1-health battle) new-health),
          player2-health: (if is-player1-turn new-health (get player2-health battle)),
          winner: (if (is-eq new-health u0)
                    (some (if is-player1-turn (get player1 battle) (get player2 battle)))
                    none),
          status: (if (is-eq new-health u0) "finished" "active")
        }
      )
    )
    
    (if (is-eq new-health u0)
      (begin
        (update-battle-stats (get player1 battle) (get player2 battle) is-player1-turn)
        (end-battle battle-id)
      )
      (ok true)
    )
  )
)

;; Calculate damage based on creature stats
(define-private (calculate-damage (creature {owner: principal, name: (string-ascii 32), creature-type: (string-ascii 16), health: uint, attack: uint, defense: uint, speed: uint, level: uint, experience: uint, in-battle: bool}) (bonus uint))
  (+ (get attack creature) bonus (/ (get level creature) u2))
)

;; Update battle statistics
(define-private (update-battle-stats (player1 principal) (player2 principal) (player1-won bool))
  (let 
    (
      (p1-stats (default-to {wins: u0, losses: u0, total-battles: u0} 
                           (map-get? battle-history player1)))
      (p2-stats (default-to {wins: u0, losses: u0, total-battles: u0} 
                           (map-get? battle-history player2)))
    )
    (map-set battle-history player1
      {
        wins: (if player1-won (+ (get wins p1-stats) u1) (get wins p1-stats)),
        losses: (if player1-won (get losses p1-stats) (+ (get losses p1-stats) u1)),
        total-battles: (+ (get total-battles p1-stats) u1)
      }
    )
    (map-set battle-history player2
      {
        wins: (if player1-won (get wins p2-stats) (+ (get wins p2-stats) u1)),
        losses: (if player1-won (+ (get losses p2-stats) u1) (get losses p2-stats)),
        total-battles: (+ (get total-battles p2-stats) u1)
      }
    )
    true
  )
)

;; End battle and free creatures
(define-private (end-battle (battle-id uint))
  (let 
    (
      (battle (unwrap! (map-get? battles battle-id) err-not-found))
      (creature1 (unwrap! (map-get? creatures (get creature1-id battle)) err-not-found))
      (creature2 (unwrap! (map-get? creatures (get creature2-id battle)) err-not-found))
    )
    (map-set creatures (get creature1-id battle)
      (merge creature1 {in-battle: false, experience: (+ (get experience creature1) u10)})
    )
    (map-set creatures (get creature2-id battle)
      (merge creature2 {in-battle: false, experience: (+ (get experience creature2) u5)})
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-creature (creature-id uint))
  (map-get? creatures creature-id)
)

(define-read-only (get-player-creatures (player principal))
  (map-get? creature-owners player)
)

(define-read-only (get-battle (battle-id uint))
  (map-get? battles battle-id)
)

(define-read-only (get-battle-stats (player principal))
  (map-get? battle-history player)
)

;; Admin functions
(define-public (set-mint-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set mint-price new-price)
    (ok true)
  )
)