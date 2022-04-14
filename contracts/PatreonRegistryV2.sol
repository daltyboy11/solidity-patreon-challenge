//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./PatreonRegistry.sol";
import "./PatreonV2.sol";

contract PatreonRegistryV2 is Ownable, PatreonRegistry {

    VRFCoordinatorV2Interface public COORDINATOR = VRFCoordinatorV2Interface(0x6168499c0cFfCaCD319c818142124B7A15E857ab);
    uint64 public chainlinkSubscriptionId;
    bool private didInit = false;

    constructor(uint64 _chainlinkSubscriptionId) Ownable() {
        chainlinkSubscriptionId = _chainlinkSubscriptionId;
    }

    function setChainlinkSubscriptionId(uint64 _chainlinkSubscriptionId) external onlyOwner {
        chainlinkSubscriptionId = _chainlinkSubscriptionId;
    }

    function acceptSubscriptionOwnerTransfer(uint64 _chainlinkSubscriptionId) external onlyOwner {
        // Once this contract has accepted subscription ownership it can programatically
        // make new PatreonV2 contracts consumers. Before calling this function, owner() must
        // call COORDINATOR.requestSubscriptionOwnerTransfer specifying this contract as the
        // recipient
        COORDINATOR.acceptSubscriptionOwnerTransfer(_chainlinkSubscriptionId);
    }

    function returnSubscriptionToOwner(uint64 _chainlinkSubscriptionId) external onlyOwner {
        // Optionally the owner can transfer subscription ownership back to themselves by
        // calling this function and then calling COORDINATOR.acceptSubscriptionOwnerTransfer
        COORDINATOR.requestSubscriptionOwnerTransfer(_chainlinkSubscriptionId, owner());
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

        COORDINATOR.addConsumer(chainlinkSubscriptionId, patreonAddress);
        isPatreonContract[patreonAddress] = true;
        address[] storage patreons = ownerToPatreons[msg.sender];
        patreons.push(patreonAddress);
        numPatreons += 1;
        patreon.transferOwnership(msg.sender);
        emit CreatePatreon(msg.sender, patreons[patreons.length-1], block.timestamp, _description);
        return patreonAddress;
    }
}
