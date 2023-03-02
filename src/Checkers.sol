// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Checkers {
    uint96 public board;
    uint8 public turn;
    uint8 private STATUS_LENGTH = 6;

    constructor() {
        // This represents the initial board set up, when interpreted as bits
        // 3 bits per square, 32 squares, 32 * 3 = 96 bits
        // board = 22636617860888976035227669065;
        board = 19807040628566647898095222784;
        turn = 1;
    }

    // function setNumber(uint96 newNumber) public {
    //     board = newNumber;
    // }

    function increment() public {
        board++;
    }

    function move(uint8 from, uint8 to) public {
        // TODO: make it so that only one instance of a contract can run at a time
        uint8 piece = isTransitionValid(from, to);
        uint96 updated = setPiece(board, from, piece);
        board = setPiece(updated, to, piece);
        turn ^= 3;
    }

    // TODO: see if bit-compaction can imporve performance here
    // combine two 96 inputs into a single 192 bit input
    function isTransitionValid(uint8 from, uint8 to)
        private
        view
        returns (uint8)
    {
        // since we are using uint, it is guranteed to be >= 0
        require(from < 31 || to < 31, "Move parameters out of bounds");

        // get pieces to be moved
        uint8 fromPiece = getPiece(from);

        // Check that the player whose turn it is is moving
        require(isTurn(fromPiece), "Invalid turn");

        // check that the destination square is empty
        require(getPiece(to) == 0, "Invalid destination: square occupied");

        // Using unchecked to allow underflow
        unchecked {
            // Expectation:
            // The result should be either 4 or 5 for a move or 7 or 9 for a jump
            // Or the same nums as above for negative when moving up the board
            // TODO: Deteremine if I even need the rollover, or can just normalize (direction can be determined using to/from)
            // (Due to rollover, negative nums will appear as either , in order)
            // since we are subtracring uint8 from another uint8, rollover can occur at most once
            // therefore there should only be one path to 255 (aka -1)
            // NOTE: Relying on underflow and int division truncation
            // TODO: do I need to specify that 8 is a uint8 to ensure that the underflow occurs as expected?
            uint8 squareDifference = from > to ? from - to : to - from;
            uint8 rowDifference = from / 4 - to / 4;

            // if not a king, validate direction
            if (fromPiece & 4 != 4) {
                if (from > to) {
                    // moving down the board - must be red
                    require(fromPiece & 2 == 2, "Invalid move direction");
                } else {
                    // moving up the board - must be white
                    require(fromPiece & 1 == 1, "Invalid move direction");
                }
            }

            if (
                (squareDifference == 4 || squareDifference == 5) &&
                (rowDifference == 1 || rowDifference == 255)
            ) {
                // destination is valid
                // Last check:
                // make sure that there are no jumps avaliable to the party making the move;
                // if jumps are avaliable, then the move is invalid
                require(
                    checkIfCanEat() == false,
                    "A capture is avaliable; must capture"
                );
            } else if (
                (squareDifference == 7 || squareDifference == 9) &&
                (rowDifference == 2 || rowDifference == 254)
            ) {
                // Eat; must move two rows over
                // check that the piece being jump over is occupied by enemy
            } else {
                // invalid move
                revert("Invalid destination square");
            }
        }

        return fromPiece;
    }

    function checkIfCanEat() public view returns (bool) {
        /* TODO: edge cases
         * 1. Eating and jumping off the edge; avaliable when an enemy is on the lower/right/left edge
         *   and your piece is on the following row (going up the board)
         */

        // a uint24 stores the status of the previous row
        // Looking backwards, we can determine the status of the current row
        // Status: 3 bits (4 black cells in a row: 3 * 4 = 12 bits required)
        // Statuses:
        // 100000 (32) - own piece
        // 010000 (16) - enemy piece
        // see below for enemy piece statuses

        uint24 previousRow = 0;
        uint24 curRow = 0;

        for (uint8 i = 0; i < 32; i++) {
            uint8 piece = getPiece(i);
            uint8 column = i % 4;
            bool leftAlignedRow = (i / 4) % 2 == 0;

            // get adjecent pieces that can be eaten are threatening the current square
            uint8 right;
            uint8 left;

            (right, left) = getNeighbours(leftAlignedRow, previousRow, column);

            if (piece != 0) {
                if (isTurn(piece)) {
                    curRow = curRow | uint24(32 << (column * STATUS_LENGTH));

                    // TODO: check scenario where we are at the edges
                    // and you would jump off the board when you eat

                    if (left & 16 == 16 && left & 8 == 8) {
                        // if enemey in left cell, and back is open
                        return true;
                    }

                    if (right & 16 == 16 && right & 4 == 4) {
                        // if enemey in right cell, and back is open
                        return true;
                    }
                } else {
                    // Enemy status:
                    // 010000  (16) - enemy piece
                    // Enemy status:
                    // 001000 (8) - Left - back empty
                    // 000100 (4) - Right - back empty
                    // 000010 (2) - Left - threatened
                    // 000001 (1) - Right - threatened

                    uint24 status = 16; // enemy

                    if (left == 32) {
                        status = status | 2;
                    } else if (left == 0) {
                        status = status | 8;
                    }

                    if (right == 32) {
                        status = status | 1;
                    } else if (right == 0) {
                        status = status | 4;
                    }

                    curRow = curRow | (status << (column * STATUS_LENGTH));
                }
            } else {
                // we are in an empty cell; check for any possible pieces that can land here
                // if the left cell is threatened from the left, the piece can jump to this cell
                if (left & 16 == 16 && left & 2 == 2) {
                    // if enemey in left cell, and threatened from the left
                    return true;
                }

                if (right & 16 == 16 && right & 1 == 1) {
                    // if enemey in right cell, and threatened from the right
                    return true;
                }
            }

            if (column == 3) {
                previousRow = curRow;
                curRow = 0;
            }
        }

        return false;
    }

    function getNeighbours(
        bool leftAlignedRow,
        uint24 previousRow,
        uint8 column
    ) public view returns (uint8, uint8) {
        uint8 STATUS = 63;
        uint8 equal = uint8((previousRow >> (column * STATUS_LENGTH)) & STATUS);

        if (leftAlignedRow) {
            return (
                equal,
                column < 3
                    ? uint8(
                        (previousRow >> ((column + 1) * STATUS_LENGTH)) & STATUS
                    )
                    : 0
            );
        } else {
            return (
                column > 0
                    ? uint8(
                        (previousRow >> ((column - 1) * STATUS_LENGTH)) & STATUS
                    )
                    : 0,
                equal
            );
        }
    }

    function getPiece(uint8 position) public view returns (uint8) {
        // gets the 3 bits at target position
        return uint8(board >> (position * 3)) & 7;
    }

    function isTurn(uint8 piece) public view returns (bool) {
        // Set king to 0 (& 3), then check equality with player turn
        // if the piece is the same as the player whose turn it is,
        // then they will cancel each other out (with the ^ operations) and result in a zero.
        // Anything else will lead to a non zero number
        // TODO: Verify king check works
        return (piece & 3) ^ turn == 0;
    }

    function setPiece(
        uint96 boardCopy,
        uint8 position,
        uint8 piece
    ) private pure returns (uint96) {
        return boardCopy ^ (uint96(piece) << (position * 3));
    }
}
