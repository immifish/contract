// SPDX-License-Identifier: MIT
pragma solidity =0.8.29;

library Int257Lib {
    struct Int257 {
        uint256 magnitude;
        bool negative;
    }

    function fromUint256(uint256 magnitude, bool negative) internal pure returns (Int257 memory) {
        require(magnitude != 0 || !negative, "Int257: zero cannot be negative");
        return Int257(magnitude, negative);
    }

    function isNegative(Int257 storage a) internal view returns (bool) {
        return a.negative;
    }

    function addStorage(Int257 storage a, uint256 b) internal {
        if (a.negative) {
            if (b >= a.magnitude) {
                a.magnitude = b - a.magnitude;
                a.negative = false;
            } else {
                a.magnitude -= b;
                // still negative
            }
        } else {
            uint256 sum = a.magnitude + b;
            require(sum >= a.magnitude, "Int257: overflow in add");
            a.magnitude = sum;
            // still positive
        }
        if (a.magnitude == 0) {
            a.negative = false;
        }
    }

    function addMemory(Int257 memory a, uint256 b) internal pure returns (Int257 memory) {
        if (a.negative) {
            if (b >= a.magnitude) {
                return Int257(b - a.magnitude, false);
            } else {
                return Int257(a.magnitude - b, true);
            }
        } else {
            uint256 sum = a.magnitude + b;
            require(sum >= a.magnitude, "Int257: overflow in add");
            return Int257(sum, false);
        }
    }

    function subStorage(Int257 storage a, uint256 b) internal {
        if (a.negative) {
            uint256 sum = a.magnitude + b;
            require(sum >= a.magnitude, "Int257: overflow in neg-sub");
            a.magnitude = sum;
            // still negative
        } else {
            if (a.magnitude >= b) {
                a.magnitude -= b;
                // still positive
            } else {
                a.magnitude = b - a.magnitude;
                a.negative = true;
            }
        }
        if (a.magnitude == 0) {
            a.negative = false;
        }
    }

    function subMemory(Int257 memory a, uint256 b) internal pure returns (Int257 memory) {
        if (a.negative) {
            uint256 sum = a.magnitude + b;
            require(sum >= a.magnitude, "Int257: overflow in neg-sub");
            return Int257(sum, false);
        } else {
            if (a.magnitude >= b) {
                return Int257(a.magnitude - b, true);
            } else {
                return Int257(b - a.magnitude, false);
            }
        }
    }
    
}