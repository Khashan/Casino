pragma solidity ^0.8.4;

import "../../libs/Factory/IFactoryLottery.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./Lottery.sol";
import "./LotteryPhase.sol";

contract FactoryLottery is IFactoryLottery, Ownable, Clones {
    Lottery[] lotteries;
    LotteryPhase lotteryPhase;
    ICasino casino;

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
        address _lpToken,
        uint256 _gameCost,
        uint256 _initPool
    ) external override {
        Lottery lottery = Lottery(createClone(masterLottery));
        lottery.init(
            casino,
            owner(),
            msg.sender,
            _lpToken,
            lotteryPhase,
            _gameCost,
            creationCost,
            _initPool
        );
        lotteries.push(child);
    }

    function setCreationCost(uint256 cost) external override {
        creationCost = cost;
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
