// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ReferralSystem
 * @dev Optimized referral system with consolidated delegation handling
 */
abstract contract ReferralSystem is Ownable, ReentrancyGuard {
    struct ReferralDetails {
        address referrer;
        uint256 totalReferrals;
        uint256 totalReferralEarnings;
        bool isActive;
        uint256 lastRewardTimestamp;
    }

    struct DelegationDetail {
        address delegatedAddress;
        uint256 sharePercentage;
    }

    // Constants
    uint256 public constant REFERRAL_REWARD_PERCENTAGE = 5;
    uint256 public constant MIN_REFERRAL_CODE_LENGTH = 4;
    uint256 public constant MAX_REFERRAL_CODE_LENGTH = 10;
    uint256 public constant MAX_DELEGATIONS_PER_USER = 5;

    // Mappings
    mapping(address => ReferralDetails) public referralDetails;
    mapping(string => address) internal referralCodeToAddress;
    mapping(address => string) public addressToReferralCode;
    mapping(address => bool) public hasCreatedReferralCode;
    mapping(address => mapping(uint256 => DelegationDetail[])) public nftDelegations;

    // Events
    event ReferralCodeCreated(address indexed user, string referralCode);
    event ReferralRewardDistributed(address indexed referrer, address indexed referee, uint256 rewardAmount);
    event DelegationUpdated(address indexed owner, uint256 indexed nftId, DelegationDetail[] delegations);
    event ReferralStatusUpdated(address indexed user, bool isActive);

    modifier validReferralCode(string memory code) {
        require(bytes(code).length >= MIN_REFERRAL_CODE_LENGTH, "Code too short");
        require(bytes(code).length <= MAX_REFERRAL_CODE_LENGTH, "Code too long");
        _;
    }

    function createReferralCode(string memory _code) external validReferralCode(_code) {
        require(!hasCreatedReferralCode[msg.sender], "Already has referral code");
        require(referralCodeToAddress[_code] == address(0), "Code already exists");

        referralCodeToAddress[_code] = msg.sender;
        addressToReferralCode[msg.sender] = _code;
        hasCreatedReferralCode[msg.sender] = true;

        referralDetails[msg.sender] = ReferralDetails({
            referrer: msg.sender,
            totalReferrals: 0,
            totalReferralEarnings: 0,
            isActive: true,
            lastRewardTimestamp: block.timestamp
        });

        emit ReferralCodeCreated(msg.sender, _code);
    }

    function updateDelegation(
        uint256 nftId, 
        DelegationDetail[] memory delegations
    ) external virtual {
        require(delegations.length <= MAX_DELEGATIONS_PER_USER, "Too many delegations");
        
        uint256 totalShare = 0;
        for (uint256 i = 0; i < delegations.length; i++) {
            require(delegations[i].delegatedAddress != address(0), "Invalid delegate");
            require(delegations[i].sharePercentage > 0, "Invalid share");
            totalShare += delegations[i].sharePercentage;
        }
        require(totalShare == 100, "Total share must be 100");

        delete nftDelegations[msg.sender][nftId];
        for (uint256 i = 0; i < delegations.length; i++) {
            nftDelegations[msg.sender][nftId].push(delegations[i]);
        }

        emit DelegationUpdated(msg.sender, nftId, delegations);
    }

    function processReferralReward(
        address referrer,
        uint256 purchaseAmount
    ) internal virtual returns (uint256) {
        require(referrer != address(0), "Invalid referrer");
        ReferralDetails storage details = referralDetails[referrer];
        require(details.isActive, "Referrer not active");

        uint256 reward = (purchaseAmount * REFERRAL_REWARD_PERCENTAGE) / 100;
        details.totalReferrals++;
        details.totalReferralEarnings += reward;
        details.lastRewardTimestamp = block.timestamp;

        emit ReferralRewardDistributed(referrer, msg.sender, reward);
        return reward;
    }

    function getDelegations(
        address owner,
        uint256 nftId
    ) external view returns (DelegationDetail[] memory) {
        return nftDelegations[owner][nftId];
    }

    function setReferralStatus(address user, bool isActive) external onlyOwner {
        referralDetails[user].isActive = isActive;
        emit ReferralStatusUpdated(user, isActive);
    }

    function _validateReferralCode(
        string memory code,
        address user
    ) internal view returns (address) {
        if (bytes(code).length == 0) return address(0);
        
        address referrer = referralCodeToAddress[code];
        require(referrer != user, "Cannot self-refer");
        require(referralDetails[referrer].isActive, "Referrer not active");
        
        return referrer;
    }
}