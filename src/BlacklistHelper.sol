// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

abstract contract BlacklistHelper {
    /// @dev Wallet Sentinal
    address internal constant SENTINEL_WALLETS = address(0x1);

    /// @dev Counters
    uint256 internal whitelistedCount;
    uint256 internal blacklistedCount;

    /// @dev Listed info
    mapping(address => address) internal whitelisted;
    mapping(address => address) internal blacklisted;

    /// @dev Events
    event AddToWhitelist(address[] user);
    event AddToBlacklist(address[] user);
    event DropFromWhitelist(address indexed user);
    event DropFromBlacklist(address indexed user);

    /// @dev Errors
    error userAlreadyOnWhitelist();
    error userAlreadyOnBlacklist();

    /// @dev Modifier for Valid if wallet is Zero Address or Not
    modifier validAddress(address to) {
        if (to == address(0)) revert("Invalid address (Address Zero)");
        _;
    }

    /// @dev Modifier for Valid if wallet is Blacklisted or Not
    modifier Blacklisted(address _user) {
        if (isBlacklisted(_user)) revert("Wallet is blacklisted");
        _;
    }

    /// @dev Modifier for Valid if wallet is Whitelisted or Not
    modifier Whitelisted(address _user) {
        if (!isWhitelisted(_user)) revert("Wallet is not whitelisted");
        _;
    }

    constructor() {}

    /// @dev Funtion to Add Wallet to Whitelist based on Approach of Safe Contract - Owner Manager
    /// @param user Array of Address of the Wallet to be added to Whitelist
    function addToWhiteList(address[] memory user) external {
        if (user.length == 0) revert("Invalid wallet (Array Zero)");
        address currentWallet = SENTINEL_WALLETS;
        for (uint256 i = 0; i < user.length; i++) {
            address wallet = user[i];
            if (
                wallet == address(0) || wallet == SENTINEL_WALLETS
                    || wallet == address(this) || currentWallet == wallet
            ) revert("Invalid wallet provided");
            // Avoid duplicate wallet
            if (whitelisted[wallet] != address(0)) {
                revert userAlreadyOnWhitelist();
            }
            // Add wallet to whitelist
            whitelisted[currentWallet] = wallet;
            currentWallet = wallet;
        }
        whitelisted[currentWallet] = SENTINEL_WALLETS;
        whitelistedCount += user.length;
        emit AddToWhitelist(user);
    }

    function addToBlackList(address[] memory user) external {
        emit AddToBlacklist(user);
    }

    function DropFromWhiteList(address user) external validAddress(user) {
        emit DropFromWhitelist(user);
    }

    /// @dev Funtion to Drop Wallet from Blacklisted based on Approach of Safe Contract - Owner Manager
    /// @param user Array of Address of the Wallet to be dropped to Blacklist
    function dropFromBlacklist(address user) external validAddress(user) {
        address prevUser = getPrevUser(user);
        blacklisted[prevUser] = blacklisted[user];
        blacklisted[user] = address(0);
        blacklistedCount--;
        emit DropFromBlacklist(user);
    }

    function isWhitelisted(address wallet) public view returns (bool) {
        return wallet != SENTINEL_WALLETS && whitelisted[wallet] != address(0)
            && wallet != address(0);
    }

    function isBlacklisted(address wallet) public view returns (bool) {
        return wallet != SENTINEL_WALLETS && blacklisted[wallet] != address(0)
            && wallet != address(0);
    }

    function getAllWhilisted() public view returns (address[] memory result) {
        result = new address[](whitelistedCount);
        address currentWallet = whitelisted[SENTINEL_WALLETS];
        uint256 i = 0;
        while (currentWallet != SENTINEL_WALLETS) {
            result[i] = currentWallet;
            currentWallet = whitelisted[currentWallet];
            i++;
        }
        return result;
    }

    function getAllBlacklisted()
        public
        view
        returns (address[] memory result)
    {
        result = new address[](blacklistedCount);
        address currentWallet = blacklisted[SENTINEL_WALLETS];
        uint256 i = 0;
        while (currentWallet != SENTINEL_WALLETS) {
            result[i] = currentWallet;
            currentWallet = blacklisted[currentWallet];
            i++;
        }
        return result;
    }

    /// TODO: Need to Validate if this logic is correct!!
    /// @dev Function to get the Previous User of the Wallet
    /// @param user Address of the Wallet
    function getPrevUser(address user)
        internal
        view
        returns (address prevUser)
    {
        prevUser = SENTINEL_WALLETS;
        address currentWallet = whitelisted[prevUser];
        while (currentWallet != SENTINEL_WALLETS) {
            if (currentWallet == user) {
                return prevUser;
            }
            prevUser = currentWallet;
            currentWallet = whitelisted[currentWallet];
        }
        return prevUser;
    }
}
