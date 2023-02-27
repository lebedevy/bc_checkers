// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Checkers {
    uint96 public board;
    uint8 public turn;

    constructor() {
        // This represents the initial board set up, when interpreted as bits
        // 3 bits per square, 32 squares, 32 * 3 = 96 bits
        board = 22636617860888976035227669065;
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
        require(from < 31 || to < 31, "Invalid square");

        // Using unchecked to allow underflow
        unchecked {
            // Expectation:
            // The result should be either 1 or -1
            // (-1 will be represented as 255 due to uint rollover)
            // since we are subtracring uint8 from another uint8, rollover can occur at most once
            // therefore there should only be one path to 255 (aka -1)
            // NOTE: Relying on underflow and int division truncation
            // TODO: do I need to specify that 8 is a uint8 to ensure that the underflow occurs as expected?
            uint8 rowDifference = from / 8 - to / 8;
            // must move to an adjecent row
            require(
                rowDifference == 1 || rowDifference == 255,
                "Invalid destination: non-adjecent square"
            );
        }

        // check that the destination square is empty
        require(getPiece(to) == 0, "Invalid destination: square occupied");

        // get pieces to be moved
        uint8 fromPiece = getPiece(from);

        // check that the player whose turn it is is moving
        // Set king to 0 to check equality with player turn
        // TODO: Make work with king pieces
        require(fromPiece ^ turn == 0, "Invalid turn");

        return fromPiece;
    }

    function getPiece(uint8 position) public view returns (uint8) {
        // gets the 3 bits at target position
        return uint8(board >> (position * 3)) & 7;
    }

    function setPiece(
        uint96 boardCopy,
        uint8 position,
        uint8 piece
    ) private pure returns (uint96) {
        return boardCopy ^ (uint96(piece) << (position * 3));
    }
}
