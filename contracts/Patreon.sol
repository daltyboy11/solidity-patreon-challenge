//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./IPatreon.sol";
import "./PatreonRegistry.sol";

contract Patreon is IPatreon, OwnableUpgradeable {
    uint public override subscriptionFee;
    uint public override subscriptionPeriod;
    uint public override ownerBalance;
    uint public override subscriberCount;
    string public override description;
    address private registryAddress;
    mapping(address => Subscriber) internal _subscribers;

    modifier onlySubscriber() {
        if(!_subscribers[msg.sender].isSubscribed)
            revert Unauthorized(msg.sender);
        _;
    }
    
    modifier onlyNonSubscriber() {
        if (_subscribers[msg.sender].isSubscribed)
            revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyNonOwner() {
        if (msg.sender == owner())
            revert Unauthorized(msg.sender);
        _;
    }

    function initialize(
        address _registryAddress,
        uint _subscriptionFee,
        uint _subscriptionPeriod,
        string memory _description
    ) public initializer {
        __Ownable_init();
        registryAddress = _registryAddress;
        subscriptionFee = _subscriptionFee;
        subscriptionPeriod = _subscriptionPeriod;
        description = _description;
    }

    function subscribe()
        external
        payable
        override
        onlyNonSubscriber
        onlyNonOwner
    {
        if (msg.value < subscriptionFee)
            revert InsufficientFunds(subscriptionFee, msg.value);

        Subscriber storage subscriber = _subscribers[msg.sender];
        ownerBalance += subscriptionFee;
        subscriber.balance += (msg.value - subscriptionFee);
        subscriber.isSubscribed = true;
        subscriber.subscribedAt = block.timestamp;
        subscriber.lastChargedAt = block.timestamp;
        subscriberCount += 1;
        emit Subscribed(msg.sender, msg.value, block.timestamp);

        PatreonRegistry(registryAddress).registerPatreonSubscription(msg.sender);
    }

    function unsubscribe()
        external
        override
        onlySubscriber
    {
        Subscriber storage subscriber = _subscribers[msg.sender];
        uint remainingSubscriptionBalance = subscriber.balance;
        subscriber.balance = 0;
        subscriber.isSubscribed = false;
        subscriberCount -= 1;
        emit Unsubscribed(msg.sender, remainingSubscriptionBalance, block.timestamp);
    } 

    function chargeSubscription(address[] calldata subscribers)
        external
        virtual
        override
        onlyOwner
    {
        for (uint i = 0; i < subscribers.length; i = i + 1) {
            Subscriber storage subscriber = _subscribers[subscribers[i]];
            // We can charge a subscriber iff `isSubscribed` == true && `lastChargedAt` + `subscriptionPeriod` >= `block.timestamp`.abi
            // Simply ignore addresses that don't match this criteria
            if (!subscriber.isSubscribed || subscriber.lastChargedAt + subscriptionPeriod > block.timestamp)
                continue;

            uint subscriptionBalanceBeforeCharge = subscriber.balance;
            if (subscriber.balance < subscriptionFee) {
                // Subscriber has insufficient funds so we transfer their balance to the owner and cancel
                // the subscription
                ownerBalance += subscriptionBalanceBeforeCharge;
                subscriber.balance = 0;
                subscriber.isSubscribed = false;
                subscriber.lastChargedAt = block.timestamp;
                subscriberCount -= 1;
                emit SubscriptionCanceled(subscribers[i], subscriptionBalanceBeforeCharge, block.timestamp);
            } else {
                // Subscriber has sufficient funds so we allocate the fee amount to the owner balance and
                // decrement it from the subscription balance.
                ownerBalance += subscriptionFee;
                subscriber.balance -= subscriptionFee;
                subscriber.lastChargedAt = block.timestamp;
            }

            emit Charged(subscribers[i], subscriptionBalanceBeforeCharge, block.timestamp);
        }
    }

    function depositFunds()
        external
        payable
        override
        onlySubscriber
    {
        _subscribers[msg.sender].balance += msg.value;
    }

    function withdraw(uint amount) external override {
        if (msg.sender == owner()) {
            withdrawOwnerBalance(amount);
        } else if (_subscribers[msg.sender].isSubscribed) {
            withdrawSubscriberBalance(amount);
        } else {
            revert Unauthorized(msg.sender);
        }
    }

    function getSubscriber(address subscriber)
        external
        view
        override
        returns (Subscriber memory)
    {
        return _subscribers[subscriber];
    }

    function withdrawOwnerBalance(uint amount) private onlyOwner {
        if (amount > ownerBalance)
            revert InsufficientFunds(amount, ownerBalance);

        ownerBalance -= amount;
        payable(owner()).transfer(amount);
    }

    function withdrawSubscriberBalance(uint amount) private onlySubscriber {
        if (amount > _subscribers[msg.sender].balance)
            revert InsufficientFunds(amount, _subscribers[msg.sender].balance);

        _subscribers[msg.sender].balance -= amount;
        payable(msg.sender).transfer(amount);
    }
}
