# Checkers

Problems to address

-   efficient storage of data to minimize cost

## Storage of the checker game data

**Problem**: What is the minimum amount of data that we can use to store the checkerboard?

Game information:

-   Checker board contains 8x8 squares (64 squares)
    -   **Optimization**: only black squares are used, so we technically only need to store 32 squares
-   12 pieces per side (24 pieces; 12 white, 12 red)

For any cell, we need to know:

-   if it has a piece
-   which player the piece belongs to
-   whether the piece is a king or a man

We can store all the data we need in 3 bits

-   bit 1: player 1 piece
-   bit 2: player 2 piece
-   bit 3: is king

3 bits \* 32 squares = 96 bits

## Game logic

Game happens on the black squares only
Two types of pieces: kings and men

-   White moves first
-   Two possible moves
    1. Simple move
        - move 1 square diagonally to a black square
        - _uncrowned pieces_: move forward only
        - _crowned_: forward and backward
    2. Jump
        - if a jump is possible, **it must be taken**
            - all possible jumps must be made
        - move diagonally, jumping over an adjecent single opponent piece; land on the empty square behind the opponent piece
            - possible to execute a sequence of jumps by a single piece
        - jumps are terminated when a piece reaches the king's row
        - _uncrowned pieces_: jump forward only
        - _crowned_: jump forward and backward

### Kings

When a man reaches the opponents king's row, it becomes a king

-   it cannot move backwards until the next turn
