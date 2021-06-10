pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../ICasino.sol";
import "../../Games/Lottery/Lottery.sol";

interface IFactoryLottery {
    function createLottery(
        IERC20 _lpToken,
        uint256 _gameCost,
        uint256 _initPool,
        uint256 _maxTicketPerUser
    ) external returns (Lottery);

    function setCreationCost(uint256 cost) external;

    function createNextLottery(Lottery oldLottery) external returns (address);
}
