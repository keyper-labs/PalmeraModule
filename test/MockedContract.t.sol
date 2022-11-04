// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MockedContractA {

    address private mockAddress = address(0x123);
    mapping(address => bool) private randomMapping;

    function randomBool(address _address) public {
        randomMapping[_address] = true;
    }

    function getMockAddress() public view returns(address) {
        return mockAddress;
    }

    function getRandomBoolValues(address _address) public view returns(bool) {
        return randomMapping[_address];
    }
}

contract MockedContractB {
    uint256 private counter;

    function incrementCounter() public {
        counter++;
    }

    function getCounter() public view returns(uint256) {
        return counter;
    }
}