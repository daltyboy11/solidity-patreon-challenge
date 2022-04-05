//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title A registry to create new IPatreon contracts and keep track of owners/subscribers to those contracts
/// @author Dalton G. Sweeney
/// @custom:experimental This is a toy interface. Use at your own risk!
interface IPatreonRegistry {

    /// @notice Check if an address is a Patreon contract minted from this registry
    function isPatreonContract(address) external view returns (bool);

    /// @notice Total number of Patreon contracts minted from this registry
    function numPatreons() external view returns (uint);

    /// @notice Mint a new Patreon contract that will be tracked by this Registry
    /// @param _subscriptionFee Fee charged the owner of the Patreon can charge their subscribers for per period
    /// @param _subscriptionPeriod Charging period for the Patreon
    /// @param _description Human readable description of the Patreon. E.g. purpose, perks unlocked, etc.
    /// @dev MUST emit a CreatePatreon event upon successfully creation such that `owner` is the message sender,
    /// `patreon` is the address of the minted contract, `createdAt` is the block timestamp, and `description`
    /// is the `_description` param
    /// @dev MUST transfer ownership of the minted contract to the message sender
    /// @return the addresses of the minted Patreon contract
    function createPatreon(
        uint _subscriptionFee,
        uint _subscriptionPeriod,
        string memory _description
    ) external returns (address);

    /// @notice called by a Patreon contract when registering a new subscriber
    /// @dev SHOULD revert if the caller is not a Patreon contract under this registry
    function registerPatreonSubscription(address subscriber) external;

    /// @notice Get the addresses of the patreon contracts owned by `owner`
    /// @param owner The address which owns of the returned Patreon contracts
    /// @return List of the addresses
    function getPatreonsForOwner(address owner) external view returns (address[] memory);

    /// @notice Get the addresses of the patreon contracts to which `subscriber` is subscribed to
    /// OR has subscribed to in the past (i.e. Patreons to which `subscriber` was subscribed but
    /// has since been unsubscribed from MUST be included)
    /// @param subscriber The address that is/was subscribed to the returned Patreon contracts
    /// @return List of the addresses
    function getPatreonsForSubscriber(address subscriber) external view returns (address[] memory);

    /// @notice Emitted when a Patreon contract is minted from this registry
    event CreatePatreon(
        address indexed owner,
        address indexed patreon,
        uint indexed createdAt,
        string description
    );

}
