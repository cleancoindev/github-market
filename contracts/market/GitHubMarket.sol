// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.6.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IMarketBehavior {
    function authenticate(
        address _prop,
        string calldata _args1,
        string calldata _args2,
        string calldata _args3,
        string calldata _args4,
        string calldata _args5,
        address market,
        address account
    )
        external
        returns (
            // solium-disable-next-line indentation
            bool
        );

    function schema() external view returns (string memory);

    function getId(address _metrics) external view returns (string memory);

    function getMetrics(string calldata _id) external view returns (address);
}

interface IMarket {
    function authenticate(
        address _prop,
        string calldata _args1,
        string calldata _args2,
        string calldata _args3,
        string calldata _args4,
        string calldata _args5
    )
        external
        returns (
            // solium-disable-next-line indentation
            bool
        );

    function authenticatedCallback(address _property, bytes32 _idHash)
        external
        returns (address);

    function deauthenticate(address _metrics) external;

    function schema() external view returns (string memory);

    function behavior() external view returns (address);

    function enabled() external view returns (bool);

    function votingEndBlockNumber() external view returns (uint256);

    function toEnable() external;
}

contract GitHubMarket is IMarketBehavior, Ownable {
    address private khaos;
    address private associatedMarket;
    address private operator;
    bool public migratable = true;
    bool public priorApproved = true;

    mapping(address => string) private repositories;
    mapping(bytes32 => address) private metrics;
    mapping(bytes32 => address) private properties;
    mapping(bytes32 => address) private markets;
    mapping(bytes32 => bool) private pendingAuthentication;
    mapping(bytes32 => bool) private authenticationed;
    mapping(string => bool) private publicSignatures;
    event Registered(address _metrics, string _repository);
    event Authenticated(string _repository, uint256 _status, string message);
    event Query(
        string githubRepository,
        string publicSignature,
        address account
    );

    /*
    _githubRepository: ex)
                        personal repository: Akira-Taniguchi/cloud_lib
                        organization repository: dev-protocol/protocol
    _publicSignature: signature string(created by Khaos)
    */
    function authenticate(
        address _prop,
        string memory _githubRepository,
        string memory _publicSignature,
        string memory,
        string memory,
        string memory,
        address _dest,
        address account
    ) external override returns (bool) {
        require(
            msg.sender == address(0) || msg.sender == associatedMarket,
            "Invalid sender"
        );

        if (priorApproved) {
            require(
                publicSignatures[_publicSignature],
                "it has not been approved"
            );
        }
        bytes32 key = createKey(_githubRepository);
        require(authenticationed[key] == false, "already authinticated");
        emit Query(_githubRepository, _publicSignature, account);
        properties[key] = _prop;
        markets[key] = _dest;
        pendingAuthentication[key] = true;
        return true;
    }

    function khaosCallback(
        string memory _githubRepository,
        uint256 _status,
        string memory _message
    ) external {
        require(msg.sender == khaos, "illegal access");
        require(_status == 0, _message);
        bytes32 key = createKey(_githubRepository);
        require(pendingAuthentication[key], "not while pending");
        emit Authenticated(_githubRepository, _status, _message);
        authenticationed[key] = true;
        register(key, _githubRepository, markets[key], properties[key]);
    }

    function register(
        bytes32 _key,
        string memory _repository,
        address _market,
        address _property
    ) private {
        address _metrics = IMarket(_market).authenticatedCallback(
            _property,
            _key
        );
        repositories[_metrics] = _repository;
        metrics[_key] = _metrics;
        emit Registered(_metrics, _repository);
    }

    function createKey(string memory _repository)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_repository));
    }

    function getId(address _metrics)
        external
        override
        view
        returns (string memory)
    {
        return repositories[_metrics];
    }

    function getMetrics(string memory _repository)
        external
        override
        view
        returns (address)
    {
        return metrics[createKey(_repository)];
    }

    function migrate(
        string memory _repository,
        address _market,
        address _property
    ) external onlyOwner {
        require(migratable, "now is not migratable");
        bytes32 key = createKey(_repository);
        register(key, _repository, _market, _property);
    }

    function done() external onlyOwner {
        migratable = false;
    }

    function setPriorApprovedMode(bool _value) external onlyOwner {
        priorApproved = _value;
    }

    function addPublicSignaturee(string memory _publicSignature) external {
        require(
            msg.sender == owner() || msg.sender == operator,
            "Invalid sender"
        );
        publicSignatures[_publicSignature] = true;
    }

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
    }

    function setKhaos(address _khaos) external onlyOwner {
        khaos = _khaos;
    }

    function setAssociatedMarket(address _associatedMarket) external onlyOwner {
        associatedMarket = _associatedMarket;
    }

    function schema() external override view returns (string memory) {
        return
            '["GitHub Repository (e.g, your/awesome-repos)", "Khaos Public Signature"]';
    }
}
