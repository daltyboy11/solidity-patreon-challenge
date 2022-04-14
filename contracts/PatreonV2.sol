//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./Patreon.sol";

contract PatreonV2 is Patreon, VRFConsumerBaseV2 {

    event FeeWaived(address indexed subscriber);

    enum ChargeStatus {
        INITIATE_CHARGE,
        PENDING_RANDOM_WORDS,
        EXECUTE_CHARGE
    }

    uint64 immutable private chainlinkSubscriptionId; 
    bytes32 public keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint32 public callbackGasLimit = 100000;
    VRFCoordinatorV2Interface public COORDINATOR;
    LinkTokenInterface public LINKTOKEN;
    ChargeStatus public chargeStatus = ChargeStatus.INITIATE_CHARGE;
    uint256 public _requestId;
    uint256[] public _randomWords;
    address[] public subscribersToCharge;

    constructor(
        address _registryAddress,
        uint _subscriptionFee,
        uint _subscriptionPeriod,
        string memory _description,
        uint64 _chainlinkSubscriptionId
    )
        Patreon(_registryAddress, _subscriptionFee, _subscriptionPeriod, _description)
        VRFConsumerBaseV2(0x6168499c0cFfCaCD319c818142124B7A15E857ab)
    {
        chainlinkSubscriptionId = _chainlinkSubscriptionId;
        COORDINATOR = VRFCoordinatorV2Interface(0x6168499c0cFfCaCD319c818142124B7A15E857ab);
        LINKTOKEN = LinkTokenInterface(0x01BE23585060835E02B77ef475b0Cc51aA1e0709);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    )
        internal
        override
    {
        require(chargeStatus == ChargeStatus.PENDING_RANDOM_WORDS, "Invalid chargeStatus");
        require(requestId == _requestId);
        _randomWords = randomWords;
        chargeStatus = ChargeStatus.EXECUTE_CHARGE;
    } 

    function chargeSubscription(address[] calldata subscribers)
        external
        override
        onlyOwner
    {
        require(subscriberCount > 0, "You need subscribers first lolz");
        require(
            chargeStatus == ChargeStatus.INITIATE_CHARGE || chargeStatus == ChargeStatus.EXECUTE_CHARGE,
            "Invalid chargeStatus"
        );

        if (chargeStatus == ChargeStatus.INITIATE_CHARGE) {
            initateCharge(subscribers);
        } else if (chargeStatus == ChargeStatus.EXECUTE_CHARGE) {
            executeCharge();
        }
    }

    function initateCharge(address[] memory subscribers) private {
        assert(chargeStatus == ChargeStatus.INITIATE_CHARGE);
        require(subscribers.length <= 500, "Exceeded VRFCoordinatorV2.MAX_NUM_WORDS");
        subscribersToCharge = subscribers;
        chargeStatus = ChargeStatus.PENDING_RANDOM_WORDS;
        _requestId = COORDINATOR.requestRandomWords(
            keyHash,
            chainlinkSubscriptionId,
            3,
            callbackGasLimit,
            uint32(subscribers.length)
        );
    }

    function executeCharge() private {
        assert(chargeStatus == ChargeStatus.EXECUTE_CHARGE);
        assert(subscribersToCharge.length == _randomWords.length);

        for (uint i = 0; i < subscribersToCharge.length; i++) {
            Subscriber storage subscriber = _subscribers[subscribersToCharge[i]];
            // We can charge a subscriber iff `isSubscribed` == true && `lastChargedAt` + `subscriptionPeriod` >= `block.timestamp`.abi
            // Simply ignore addresses that don't match this criteria
            if (!subscriber.isSubscribed || subscriber.lastChargedAt + subscriptionPeriod > block.timestamp)
                continue;
            
            // Waive the subscription fee with 1/numSubscribers probability. On average 1 subscriber
            // per period will have their subscription waived. Note the edge case with 1 subscriber
            // Based on our formula they will have a 100% chance of having the fee waived. So instead
            // we make it a 50% chance.
            if (
                subscriberCount == 1 && _randomWords[i] % 2 == 0 ||
                subscriberCount > 1 && _randomWords[i] % subscriberCount == 0
            )
            {
                // Fee is waived for this subscriber
                emit FeeWaived(subscribersToCharge[i]);
                continue;
            }

            uint subscriptionBalanceBeforeCharge = subscriber.balance;
            if (subscriber.balance < subscriptionFee) {
                // Subscriber has insufficient funds so we transfer their balance to the owner and cancel
                // the subscription
                ownerBalance += subscriptionBalanceBeforeCharge;
                subscriber.balance = 0;
                subscriber.isSubscribed = false;
                subscriber.lastChargedAt = block.timestamp;
                subscriberCount -= 1;
                emit SubscriptionCanceled(subscribersToCharge[i], subscriptionBalanceBeforeCharge, block.timestamp);
            } else {
                // Subscriber has sufficient funds so we allocate the fee amount to the owner balance and
                // decrement it from the subscription balance.
                ownerBalance += subscriptionFee;
                subscriber.balance -= subscriptionFee;
                subscriber.lastChargedAt = block.timestamp;
            }

            emit Charged(subscribersToCharge[i], subscriptionBalanceBeforeCharge, block.timestamp);
        }

        chargeStatus = ChargeStatus.INITIATE_CHARGE;
    }
}
