//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PatreonRegistry.sol";
import "./PatreonV2.sol";

contract PatreonRegistryV2 is Ownable, PatreonRegistry {

    uint64 public chainlinkSubscriptionId;

    constructor(uint64 _chainlinkSubscriptionId) Ownable() {
        chainlinkSubscriptionId = _chainlinkSubscriptionId;
    }

    function setChainlinkSubscriptionId(uint64 _chainlinkSubscriptionId) external onlyOwner {
        chainlinkSubscriptionId = _chainlinkSubscriptionId;
    }

    function createPatreon(
        uint _subscriptionFee,
        uint _subscriptionPeriod,
        string memory _description
    )
        external
        override
        returns (address)
    {
        PatreonV2 patreon = new PatreonV2(
            address(this),
            _subscriptionFee,
            _subscriptionPeriod,
            _description,
            chainlinkSubscriptionId
        );
        address patreonAddress = address(patreon);

        isPatreonContract[patreonAddress] = true;
        address[] storage patreons = ownerToPatreons[msg.sender];
        patreons.push(patreonAddress);
        numPatreons += 1;
        patreon.transferOwnership(msg.sender);
        emit CreatePatreon(msg.sender, patreons[patreons.length-1], block.timestamp, _description);
        return patreonAddress;
    }
}
