// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Checkers {
    uint96 public board;
    uint8 public turn;
    uint8 private STATUS_LENGTH = 7;
    address public player1;
    address public player2;

    constructor() {
        // This represents the initial board set up, when interpreted as bits
        // 3 bits per square, 32 squares, 32 * 3 = 96 bits
        board = 22636617860888976035227669065;
        turn = 1;
    }

    // function setNumber(uint96 newNumber) public {
    //     board = newNumber;
    // }

    function register(uint8 position) public {
        if (position == 1) {
            require(player1 == address(0), "Player 1 already taken");
            require(player2 != msg.sender, "Already registered as player 2");
            player1 = msg.sender;
        } else if (position == 2) {
            require(player2 == address(0), "Player 2 already taken");
            require(player1 != msg.sender, "Already registered as player 1");
            player2 = msg.sender;
        } else {
            revert("Invalid position");
        }
    }

    // TODO: see if bit-compaction can imporve performance here
    // combine two 96 inputs into a single 192 bit input
    function move(uint8 from, uint8 to) public {
        require(
            player1 != address(0) && player2 != address(0),
            "Two players must register for game to start"
        );

        if (turn == 1) {
            require(msg.sender == player1, "Invalid player");
        } else {
            require(msg.sender == player2, "Invalid player");
        }

        // since we are using uint, it is guranteed to be >= 0
        require(from < 31 || to < 31, "Move parameters out of bounds");

        // get pieces to be moved
        uint8 fromPiece = getPiece(from);

        // Check that the player whose turn it is is moving
        require(isTurn(fromPiece), "Invalid turn");

        // check that the destination square is empty
        require(getPiece(to) == 0, "Invalid destination: square occupied");

        // if not a king, validate direction
        if (fromPiece & 4 != 4) {
            // from > to: moving down the board - must be red
            // to > from: moving up the board - must be white
            require(
                from > to ? fromPiece & 2 == 2 : fromPiece & 1 == 1,
                "Invalid move direction"
            );
        }

        // if we normalize the cell index to include the white cells,
        // the difference between cells for a legal move will always be 7 or 9 and 14 or 18 for a jump
        uint8 fromIndex = getNormalizedIndex(from);
        uint8 toIndex = getNormalizedIndex(to);

        uint8 squareDifference;
        uint8 rowDifference;

        uint96 updatedBoard = board;

        if (fromIndex > toIndex) {
            squareDifference = fromIndex - toIndex;
            rowDifference = from / 4 - to / 4;
        } else {
            squareDifference = toIndex - fromIndex;
            rowDifference = to / 4 - from / 4;
        }

        if (
            rowDifference == 1 &&
            (squareDifference == 7 || squareDifference == 9)
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
            rowDifference == 2 &&
            (squareDifference == 14 || squareDifference == 18)
        ) {
            // Capture: must move two rows over
            uint8 squareIndex = getDenormalizedIndex((fromIndex + toIndex) / 2);
            uint8 squareJumpedOver = getPiece(squareIndex);

            // Ensure that the square being jump over is not empty and occupied by an enemy piece
            require(
                isTurn(squareJumpedOver) == false && squareJumpedOver != 0,
                "Invalid capture: no enemy piece"
            );

            // at this point move is valid; begin updating board
            // set square being jumped over to empty
            updatedBoard = setPiece(updatedBoard, squareIndex, 0);
        } else {
            // invalid move
            revert("Invalid destination square");
        }

        updatedBoard = setPiece(updatedBoard, from, 0);

        // if the piece is in the last row, it becomes a king
        if ((turn == 1 && to / 4 == 7) || (turn == 2 && to / 4 == 0)) {
            fromPiece = fromPiece | 4;
        }

        board = setPiece(updatedBoard, to, fromPiece);
        turn ^= 3;
    }

    function checkIfCanEat() public view returns (bool) {
        /* TODO: edge cases
         * 1. Eating and jumping off the edge; avaliable when an enemy is on the lower/right/left edge
         *   and your piece is on the following row (going up the board)
         */

        // a uint24 stores the status of the previous row
        // Looking backwards, we can determine the status of the current row
        // Statuses:
        // 1000000 (64) - own piece - can't eat forward (need to know for blocking purpose)
        // 0100000 (32) - own piece - can eat forward
        // 0010000 (16) - enemy piece
        // see below for enemy piece statuses

        uint32 previousRow = 0;
        uint32 curRow = 0;

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
                    bool isRed = piece & 2 == 2;
                    bool isKing = piece & 4 == 4;

                    // add own piece - can only threaten subsequent pieces if is white or is king
                    curRow =
                        curRow |
                        (uint32(isKing || !isRed ? 32 : 64) <<
                            (column * STATUS_LENGTH));

                    if (i > 7 && (isKing || isRed)) {
                        // can only eat backwards when you are in the 3rd row or further, and the piece is king or red
                        if (left & 16 == 16 && left & 8 == 8) {
                            // if enemey in left cell, and back is open
                            return true;
                        }

                        if (right & 16 == 16 && right & 4 == 4) {
                            // if enemey in right cell, and back is open
                            return true;
                        }
                    }
                } else {
                    // Enemy status:
                    // 0010000  (16) - enemy piece
                    // Enemy status:
                    // 0001000 (8) - Left - back empty
                    // 0000100 (4) - Right - back empty
                    // 0000010 (2) - Left - threatened
                    // 0000001 (1) - Right - threatened

                    uint32 status = 16; // enemy

                    if (i > 3) {
                        // do not check behind if in the first column

                        if (left == 32) {
                            status = status | 2;
                        } else if (
                            left == 0 && !(leftAlignedRow && column == 3)
                        ) {
                            // if left is empty, and it is not an edge piece on the left
                            status = status | 8;
                        }

                        if (right == 32) {
                            status = status | 1;
                        } else if (
                            right == 0 && !(!leftAlignedRow && column == 0)
                        ) {
                            // if right is empty, and not an edge square on the right
                            status = status | 4;
                        }
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
        uint32 previousRow,
        uint8 column
    ) public view returns (uint8, uint8) {
        uint8 STATUS = 127;
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
        // TODO: is it cheaper to re-calculate position, or to store it in a variable?
        // set bits to 0 at index
        uint96 bc = boardCopy & ~(uint96(7) << (position * 3));
        // set bits to piece at index
        return bc ^ (uint96(piece) << (position * 3));
    }

    function getNormalizedIndex(uint8 index) private pure returns (uint8) {
        // there are double the cells per row when we include white cells: (index % 4)
        // if we are in an even row, the white cell comes first so we have to add it to the index: (index / 4 % 2 ^ 1)
        // and we have to add all the white cells from previous rows: (index / 4 * 4)
        return index + (index % 4) + ((index / 4) % 2 ^ 1) + ((index / 4) * 4);
    }

    function getDenormalizedIndex(uint8 index) private pure returns (uint8) {
        // we have to remove all the white cells from previous rows: (index / 8 * 4)
        // if we are in an even row, the white cell comes first so we have to remove it from the index: (index / 4 % 2 ^ 1)
        // there are double the cells per row when we include white cells: ((index % 8) / 2)
        return
            index -
            ((index / 8) * 4) -
            ((index / 8) % 2 ^ 1) -
            ((index % 8) / 2);
    }
}
