pragma solidity >=0.8.4;

import "../ICasino.sol";

interface IDatabaseGame {
    function addGame(address _game) external;

    function getEndedGames() external view returns (address[] memory);

    function setCasino(ICasino _casino) external;
}
