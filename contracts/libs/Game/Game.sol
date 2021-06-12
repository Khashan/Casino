pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./IGame.sol";

abstract contract Game is IGame {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool private isInitialized = false;
    address public creator;
    address public owner;

    uint256 public gameCost;
    uint256 public tokens;
    uint256 public destroyEnds;
    bool public isDestroying;
    bool public canBeDestroyed;
    ICasino public casino;

    function _init(
        ICasino _casino,
        address _owner,
        address _creator,
        uint256 _cost,
        uint256 _initialTokens,
        bool _canBeDestroyed
    ) internal {
        require(!isInitialized, "Contract already initialized");
        casino = _casino;
        owner = _owner;

        //Dev don't pay the fee to create a new game
        if (_owner != _creator) {
            casino.takeToken(_creator, _initialTokens);
        }

        gameCost = _cost;
        creator = _creator;
        tokens = _initialTokens;
        canBeDestroyed = _canBeDestroyed;

        isInitialized = true;
    }

    function _playVerification(uint256 _usedToken) internal view {
        require(!isDestroying, "The game will be destroyed");
        require(_usedToken >= gameCost, "Didn't pay");
    }

    function requestDestroy() external isOwner {
        require(canBeDestroyed, "This game cannot be destroyed");
        destroyEnds = block.timestamp + 2 days;
        isDestroying = true;
    }

    function destroyGame() external isOwner {
        require(
            isDestroying && destroyEnds <= block.timestamp,
            "Is not ready to be destroyed"
        );

        casino.giveToken(creator, casino.getTokens(address(this)));
        selfdestruct(payable(owner));
    }

    function applyBPS(uint256 amount, uint256 bps)
        internal
        pure
        returns (uint256)
    {
        return amount.mul(bps).div(10000);
    }

    function setCost(uint256 _cost) external override isCreator {
        gameCost = _cost;
    }

    modifier isCreator {
        require(creator == msg.sender);
        _;
    }

    modifier isOwner {
        require(owner == msg.sender, "You are not owner");
        _;
    }

    modifier isAdmin {
        require(creator == msg.sender || owner == msg.sender, "Not admin");
        _;
    }
}
