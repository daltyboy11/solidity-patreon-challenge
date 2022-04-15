//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title A Patreon contract with an owner and subscribers. Anyone can subscribe and the
/// owner can periodically withdraw fees. It's up to the owner what kind of perks/benefits
/// they wish to give the active subcsribers
/// @author Dalton G. Sweeney
/// @custom:experimental This is a toy interface. Use at your own risk!
interface IPatreon {

    /// @notice Subscriber info for an address
    ///
    /// @param subscribedAt Time at which the the address subscribed. Only relevant if `isSubscribed` is `true`
    /// @param balance The balance of this address from which the address can withdraw funds and the owner can charge the fee
    /// @param isSubscribed When `true` the address is an active subscriber
    /// @param lastChargedAt Timestamp (in seconds) when the fee was last charged (either successfully or attempted)
    struct Subscriber {
        uint subscribedAt;
        uint balance;
        bool isSubscribed;
        uint lastChargedAt;
    }

    /// @notice Emitted when an address subscribes
    /// @param _address Address that was subscribed
    /// @param amountSubscribedWith Amount subscribed with in wei (i.e. msg.amount when `subscribe` was called)
    /// @param subscribedAt Epoch time in seconds at which the event was emitted
    event Subscribed(
        address indexed _address,
        uint amountSubscribedWith,
        uint indexed subscribedAt
    );

    /// @notice Emitted when an address unsubscribes
    /// @param _address Address that was subscribed
    /// @param amountUnsubscribedWith Amount unsubscribed with in wei, i.e. the balance on the Subscriber object
    /// @param unsubscribedAt Epoch time in seconds at whith the event was emitted
    event Unsubscribed(
        address indexed _address,
        uint amountUnsubscribedWith,
        uint indexed unsubscribedAt
    );

    /// @notice Emitted when a subscription is canceled because the owner charged the subscriber
    /// but the subscriber had insufficient funds to pay the subscription fee
    ///
    /// @param _address Address that had its subscription canceled
    /// @param amountCanceledWith Amount in wei of the address's balance at the time of cancellation
    /// @param canceledAt Epoch time in seconds at which the event was emitted
    event SubscriptionCanceled(
        address indexed _address,
        uint amountCanceledWith,
        uint indexed canceledAt
    );

    /// @notice Emitted when a subscriber is charged the subscription fee (either successfully or attempted)
    /// @param subscriber address of that was charged
    /// @param amount Amount charged in wei
    /// @param chargedAt Epoch time in seconds at which the event was emitted
    event Charged(
        address indexed subscriber,
        uint amount,
        uint indexed chargedAt
    );

    /// @notice Revert with this error when a balance requested exceeds the maximum allowable balance
    /// @param requested wei amount requested
    /// @param limit the maximum amount (i.e. limit < requested)
    error InsufficientFunds(uint256 requested, uint256 limit);

    /// @notice Revert with this error when unauthorized access to a function is attempted
    /// @param _address who made the failed access attempt
    error Unauthorized(address _address);

    /// @notice Human readable description, e.g. purpose, perks unlocked, etc.
    function description() external view returns (string memory);

    /// @notice Fee the owner of the Patreon may charge once per period
    /// @return Fee (wei)
    function subscriptionFee() external view returns (uint);

    /// @notice Minimum waiting period for the owner to charge a subscriber
    /// @return Waiting period (seconds). E.g. 604800 => subscription can be charged weekly
    function subscriptionPeriod() external view returns (uint);

    /// @notice Owner's balance. This is the sum of all fees paid to them by the subscribers
    /// @dev Fees are awarded to the owner when an owner subscribes and when the subscriber is charged
    /// @return Balance (wei)
    function ownerBalance() external view returns (uint);

    /// @notice Get the Subscriber object for an address
    function getSubscriber(address) external view returns (Subscriber calldata);

    /// @notice Active subscriber count
    function subscriberCount() external view returns (uint);

    /// @notice Subscribe the message sender to this Patreon.
    /// The value of the message must be at least the subscription fee because this function
    /// will transfer an amount equal to the subscription fee directly to the owner. Any
    /// remaining funds from msg.value is allocated to the sender's balance in their Subscriber
    /// object.
    ///
    /// @dev The subscription must be recorded in the registery via `registerPatreonSubscription(address subscriber)`
    /// @dev Subscription must increment the subscriber count
    /// @dev Subscription must emit a `Subscribed` event
    /// @dev Subscription must set the sender's `subscribedAt` property to `true`
    /// @dev Subscription should revert unless called by a non-owner non-subscriber
    function subscribe() external payable;

    /// @notice Unsubscribe the message sender from this Patreon. This will set the subscriber's balance
    /// to 0, so it is HIGHLY recommended the subscriber withdraws their total balance before unsubscribing
    ///
    /// @dev Unsubscription must decrement the subscriber count
    /// @dev Unsubscription must emit an `Unsubscribed` event
    /// @dev Unsubscription should revert unless called by a subscriber
    function unsubscribe() external;

    /// @notice Charge the subscription fee to the subscriber list. This can be done at most once every
    /// `subscriptionPeriod` seconds for each subscriber. Only the owner of the patreon can call this
    /// function and it's their responsibility to supply the correct subcsriber addresses. If a
    /// subscriber's balance is under the subscription fee then the remaining balance is transferred to
    /// the owner's balance and the subscriber is automatically unsubscribed.
    ///
    /// @dev A subscriber list is provided instead of internally iterating through all the subscribers
    /// to avoid hitting the gas limit. The number of subscribers could be unbounded so if we simply
    /// iterated through that list to charge the subscriptions then the gas cost of this function would
    /// also be unbounded. This interface allows the owner to break up the subscription charges into chunks
    /// @dev A `Charged` event should be emitted when any amount is tranferred from a subscriber to the owner
    /// @dev A `SubscriptionCanceled` event should be emitted if the subscriber is unsubscribed due to
    /// insufficient funds
    function chargeSubscription(address[] calldata subscribers) external;

    /// @notice A subscriber calls this function to deposit funds and maintain their balance over the fee
    function depositFunds() external payable;

    /// @notice Allow the owner or a subscriber to withdraw their funds. The address cannot withdraw more than
    /// their balance
    ///
    /// @param amount Withdrawal amount to transfer to the message sender
    function withdraw(uint amount) external;
}
