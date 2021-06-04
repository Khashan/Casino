pragma solidity ^0.8.4;

import "../../libs/Factory/IFactoryLottery.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./Lottery.sol";
import "./LotteryPhase.sol";

contract FactoryLottery is IFactoryLottery, Ownable, Clones {
    Lottery[] lotteries;
    LotteryPhase lotteryPhase;
    ICasino casino;

    mapping(address => uint256) indexLotteries;

    uint256 creationCost;
    Lottery masterLottery;

    constructor(
        ICasino _casino,
        Lottery _masterLottery,
        LotteryPhase _lotteryPhase,
        uint256 _creationCost
    ) {
        creationCost = _creationCost;
        masterLottery = _masterLottery;
        lotteryPhase = _lotteryPhase;
        casino = _casino;
    }

    function createLottery(
        IERC20 _lpToken,
        uint256 _gameCost,
        uint256 _initPool,
        uint256 _maxTicketPerUser
    ) external override {
        require(
            _lpTokne.balanceOf(_manager) >= _initPool,
            "Not enough for the initial pool"
        );

        Lottery lottery = Lottery(createClone(masterLottery));
        lottery.init(
            casino,
            this,
            owner(),
            msg.sender,
            _lpToken,
            _maxTicketPerUser,
            _gameCost,
            _initPool
        );
        lotteries.push(child);
    }

    function createNextLottery(Lottery oldLottery) external returns (Lottery) {
        require(_isLottery(oldLottery), "Only lottery can call this");
        return Lottery(createClone(masterLottery));
    }

    function setCreationCost(uint256 cost) external override {
        creationCost = cost;
    }

    function _isLottery(address lotteryAddress) internal view returns (bool) {
        uint256 index = indexLotteries[lotteryAddress];
        return lotteryAddress = lotteries[index];
    }

    function getLotteryIndex(address lotteryAddress)
        external
        view
        override
        returns (uint256)
    {
        return indexLotteries[lotteryAddress];
    }

    function getLottery(uint256 index)
        external
        view
        override
        returns (Lottery)
    {
        return lotteries[index];
    }
}
