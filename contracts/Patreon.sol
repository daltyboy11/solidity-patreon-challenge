//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IPatreon.sol";
import "./PatreonRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Patreon is IPatreon, Ownable {
    uint public immutable override subscriptionFee;
    uint public immutable override subscriptionPeriod;
    uint public override ownerBalance;
    uint public override subscriberCount;
    string public override description;

    constructor(
        address _registryAddress,
        uint _subscriptionFee,
        uint _subscriptionPeriod,
        string memory _description
    ) Ownable() {
        subscriptionFee = 0;
        subscriptionPeriod = 0;
        revert("Implement me!");
    }

    function subscribe()
        external
        payable
        override
    {
       revert("Implement me!"); 
    }

    function unsubscribe()
        external
        override
    {
        revert("Implement me!");
    } 

    function chargeSubscription(address[] calldata subscribers)
        external
        override
    {
       revert("Implement me!"); 
    }

    function depositFunds()
        external
        payable
        override
    {
        revert("Implement me!");
    }

    function withdraw(uint amount) external override {
        revert("Implement me!");
    }

    function getSubscriber(address subscriber)
        external
        view
        override
        returns (Subscriber memory)
    {
        revert("Implement me!");
    }
}
