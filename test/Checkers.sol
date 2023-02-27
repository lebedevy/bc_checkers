// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../src/Checkers.sol";

contract CounterTest is Test {
    Checkers public checkers;

    function setUp() public {
        checkers = new Checkers();
        // checkers.setNumber(0);
    }

    // function testIncrement() public {
    //     checkers.increment();
    //     assertEq(checkers.board(), 22636617860888976035227669065);
    // }

    function testNumber() public {
        // test that the initial board is set up correctly
        assertEq(checkers.board(), 22636617860888976035227669065);
    }

    // To run tests for this function, make it public
    function testGetPiece() public {
        for (uint8 i = 0; i < 32; i++) {
            if (i < 12) {
                // 12 white pieces
                assertEq(checkers.getPiece(i), 1);
            } else if (i > 19) {
                // 12 red pieces
                assertEq(checkers.getPiece(i), 2);
            } else {
                // 12 empty squares
                assertEq(checkers.getPiece(i), 0);
            }
        }
    }

    function testIsTransitionValid() public {
        // test that the initial board is set up correctly
        checkers.move(8, 12);
        assertEq(checkers.board(), 22636617860888976103930368585);
        assertEq(checkers.turn(), 2);
    }

    function testOverflow() public {
        uint8 from = 8;
        uint8 to = 19;

        uint8 t1 = to / 8;
        uint8 f1 = from / 8;

        uint8 one = 1;
        uint8 two = 2;

        unchecked {
            console.log(one - two);
            assertEq(one - two, 255);
        }

        // assertEq(f1, 1);
        // assertEq(t1, 2);
    }
}
