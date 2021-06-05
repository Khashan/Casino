pragma solidity ^0.8.4;

import "../Games/Lottery/Lottery.sol";

contract DatabaseLottery {
    Lottery[] public oldLottery;
    mapping(Lottery => bool) lotteries;

    function addLottery(Lottery lottery) external {
        require(
            lottery.currentPhase == uint8(Phase.CLOSING),
            "Lottery is not done"
        );
        require(!lotteries[lottery], "Lottery already in the db");

        lotteries[lottery] = true;
        oldLottery.push(lottery);
    }

    function getLotteries() external view returns (Lottery[]) {
        return oldLottery;
    }
}
