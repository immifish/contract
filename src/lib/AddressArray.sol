// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library AddressArray {
    function find(address[] storage array, address element) internal view returns (bool, uint256) {
        if (array.length == 0) {
            return (false, 0);
        }
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function remove(address[] storage array, address element) internal returns (bool) {
        uint256 length = array.length;
        if (length == 0) {
            return false;
        }
        for (uint256 i = 0; i < length; i++) {
            if (array[i] == element) {
                array[i] = array[length - 1];
                array.pop();
                return true;
            }
        }
        return false;
    }

    function contain(address[] memory addrs, address addr) public pure returns (bool) {
        for (uint256 i = 0; i < addrs.length; i++) {
            if (addrs[i] == addr) {
                return true;
            }
        }
        return false;
    }
}
