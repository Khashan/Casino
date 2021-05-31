pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../libs/ICasino.sol";
import "../libs/IGame.sol";

abstract contract Game is Ownable, IGame {
    using SafeMath for uint256;

    uint256 public gameCost;
    address public creator;
    uint256 public tokens;
    uint256 public destroyEnds;
    bool public isDestroying;
    ICasino public casino;

    constructor(
        ICasino _casino,
        address _owner,
        address _creator,
        uint256 _cost,
        uint256 _initialTokens
    ) {
        casino = _casino;
        transferOwnership(_owner);
        casino.takeToken(_creator, _cost);

        gameCost = _cost;
        creator = _creator;
        tokens = _initialTokens;
    }

    function cost() external view override returns (uint256) {
        return gameCost;
    }

    function _playVerification(
        address requester,
        address user,
        uint256 _usedToken
    ) internal {
        require(requester == address(casino), "Need to use Casino contract");
        require(!isDestroying, "The game will be destroyed");
        require(_usedToken >= gameCost, "Didn't pay");
    }

    function requestDestroy() external isAdmin {
        destroyEnds = block.timestamp + 2 days;
        isDestroying = true;
    }

    function destroyGame() external isAdmin {
        require(
            isDestroying && destroyEnds <= block.timestamp,
            "Is not ready to be destroyed"
        );

        casino.giveToken(creator, casino.getTokens(address(this)));
        selfdestruct(payable(owner()));
    }

    modifier isCreator {
        require(creator == msg.sender);
        _;
    }

    modifier isAdmin {
        require(
            (creator == msg.sender || owner() == msg.sender),
            "You are not admin"
        );
        _;
    }
}
