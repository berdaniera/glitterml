// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts@4.4.0/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "https://github.com/ernestognw/openzeppelin-contracts/blob/feature/add-base64-library-%232859/contracts/utils/Base64.sol";
import "https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol";
import "hardhat/console.sol";

contract W3DS is ERC1155 {
    constructor() ERC1155("") {
        console.log("Good morning!");
    }

    struct ModelAttributes {
        string name;
        string modelType;
        int128[] coefficients;
        string metadata;
    }

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint256 => ModelAttributes) private allModels;

    function stringMatches(
        string memory string1, string memory string2
    ) private pure returns (
        bool
    ) {
        return keccak256(bytes(string1)) == keccak256(bytes(string2));
    }

    function mint (
        string memory modelName,
        string memory modelType,
        string memory modelMetadata,
        int128[] memory coefficients
    ) public {
        require(
            stringMatches(modelType, "linear") || stringMatches(modelType, "logistic"),
            "Model type must be linear or logistic."
        );
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId, 1, "");
        allModels[newItemId] = ModelAttributes({
            name: modelName,
            modelType: modelType,
            metadata: modelMetadata,
            coefficients: coefficients
        });
        _tokenIds.increment();
        console.log("Minted model %s", newItemId);
    }

    function update (
        uint256 _tokenId,
        int128[] memory newCoefficients
    ) public {
        // check if the sender owns the token
        require(
            balanceOf(msg.sender, _tokenId) == 1, // they're all unique
            "You do not own this token."
        );
        // if yes, update the coefficients
        ModelAttributes storage thisModel = allModels[_tokenId];
        thisModel.coefficients = newCoefficients;
        console.log("Updated model %s with new coefficients", _tokenId);
    }

    function uri (
        uint256 _tokenId
    ) override public view returns (
        string memory
    ) {
        ModelAttributes memory thisModel = allModels[_tokenId];

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',thisModel.name,' ',Strings.toString(_tokenId),'", ',
                        '"description": "A linear model", ',
                        '"image": "https://storage.googleapis.com/opensea-prod.appspot.com/puffs/3.png", ',
                        '"attributes": ',thisModel.metadata,'}}'
                    )
                )
            )
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    //function metadata(uint256 _tokenId) public view returns (string memory) { uri(_tokenId); }

    function predict (
        uint256 _tokenId, int128[] memory predictors
    ) public view returns (
        int128
    ) {
        ModelAttributes memory thisModel = allModels[_tokenId];
        int128[] memory coefficients = thisModel.coefficients;
        // TODO: if length of coefficients does not match length of predictors, throw an error
        //int linearPred = predLinear(coefficients, predictors);
        if (stringMatches(thisModel.modelType, "linear")) {
            int128 prediction = predLinear(coefficients, predictors);
            return prediction;
        } else if (stringMatches(thisModel.modelType, "logistic")) {
            int128 prediction = predLogistic(coefficients, predictors);
            return prediction;
        } else {
            return 0;
        }
    }

    function predLinear (
        int128[] memory coefficients, int128[] memory predictors
    ) private pure returns (
        int128
    ) {
        int128 val = 0;
        for (uint i = 0; i < coefficients.length; i++) {
            val += coefficients[i] * predictors[i] / 1e6; // keep it scaled to 1e6 fixed point
        }
        return val;
    }

    function logistic (int128 x) private pure returns (int128) {
        if (x < -15e6) return 0; // underflow
        // first, rescale the link value and get the natural exponent
        // of the signed 64.64-bit fixed point number
        int128 expx = ABDKMath64x64.exp( (-x / 1e6) * 2**64 );
        // then, calculate the logistic function and rescale to 1e6
        return 1e6 * 2**64 / ( 2**64 + expx );
    }

    function predLogistic (
        int128[] memory coefficients, int128[] memory predictors
    ) private pure returns (
        int128
    ){
        // first, calculate the link function, then calculate the inverse-logit
        int128 link = predLinear(coefficients, predictors);
        return logistic(link);
    }

}
