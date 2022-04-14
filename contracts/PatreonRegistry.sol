//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IPatreonRegistry.sol";
import "./Patreon.sol";

contract PatreonRegistry is IPatreonRegistry {
    mapping(address => bool) public override isPatreonContract;
    uint public override numPatreons;

    // Track the Patreon contracts owned by an EOA
    mapping(address => address[]) internal ownerToPatreons;
    // Track the Patreon contracts to which an EOA is currently subscribed
    // or has subscribed to in the past
    mapping(address => address[]) private subscriberToPatreons;
    mapping(address => mapping (address => bool)) private subscriberAlreadySubscribed;

    modifier onlyPatreonContract {
        require(
            isPatreonContract[msg.sender],
            "Only registered Patreon contracts can call this function"
        );
        _;
    }

    /// Create a new Patreon contract and assign it to the caller.
    /// The contract address will appear in the `ownerToPatreons` map.
    function createPatreon(
        uint _subscriptionFee,
        uint _subscriptionPeriod,
        string memory _description
    )
        virtual
        external
        override
        returns (address)
    {
        Patreon patreon = new Patreon(
            address(this),
            _subscriptionFee,
            _subscriptionPeriod,
            _description
        );

        isPatreonContract[address(patreon)] = true;
        address[] storage patreons = ownerToPatreons[msg.sender];
        patreons.push(address(patreon));
        numPatreons += 1; 

        // Transfer ownership from the registry to the minter
        patreon.transferOwnership(msg.sender);

        emit CreatePatreon(
            msg.sender,
            patreons[patreons.length - 1],
            block.timestamp,
            _description
        );

        return address(patreon);
    }

    /// Called by a Patreon contract when it receives a new subscriber.
    /// The Patreon contract address is added to the subscriber's list
    /// of subcsriptions in the `subcsriberToPatreons` map.
    function registerPatreonSubscription(address subscriber)
        external
        override
        onlyPatreonContract
    {
        if (!subscriberAlreadySubscribed[subscriber][msg.sender]) {
            subscriberToPatreons[subscriber].push(msg.sender);
            subscriberAlreadySubscribed[subscriber][msg.sender] = true;
        }
    }

    /// Fetch the list of Patreon contracts owned by the address.
    function getPatreonsForOwner(address owner)
        external
        view
        override
        returns (address[] memory)
    {
        return ownerToPatreons[owner];
    }

    /// Fetch the list of Patreon contracts to which the address is
    /// subscribed OR has subscribed to in the past. 
    function getPatreonsForSubscriber(address subscriber)
        external
        view
        override
        returns (address[] memory)
    {
        return subscriberToPatreons[subscriber];
    }
}
