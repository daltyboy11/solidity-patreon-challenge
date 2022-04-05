//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IPatreonRegistry.sol";
import "./Patreon.sol";

contract PatreonRegistry is IPatreonRegistry {
    mapping(address => bool) public override isPatreonContract;
    uint public override numPatreons;

    function createPatreon(
        uint _subscriptionFee,
        uint _subscriptionPeriod,
        string memory _description
    )
        external
        override
        returns (address)
    {
        revert("Implement me!");
    }

    function registerPatreonSubscription(address subscriber)
        external
        override
    {
        revert("Implement me!");
    }

    function getPatreonsForOwner(address owner)
        external
        view
        override
        returns (address[] memory)
    {
        revert("Implement me!");
    }

    function getPatreonsForSubscriber(address subscriber)
        external
        view
        override
        returns (address[] memory)
    {
        revert("Implement me!");
    }
}
