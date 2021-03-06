pragma solidity >=0.8.4;

import "../ICasino.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IDatabaseUser {
    struct User {
        address[] gamesParticipated;
        address[] gamesCreated;
        address[] gamesWon;
    }

    function setCasino(ICasino _casino) external;

    function userWon(address user) external;

    function userCreated(address user) external;

    function userJoined(address user) external;

    function getUser(address user) external view returns (User memory);
}
