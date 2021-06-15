pragma solidity >=0.8.4;

import "../ICasino.sol";
import "../Database/IDatabaseGame.sol";

interface IFactory {
    function setCasino(ICasino _casino) external;

    function setGameDatabase(IDatabaseGame _dbGame) external;
}
