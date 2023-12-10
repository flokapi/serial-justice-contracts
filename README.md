



# Getting started

## Preparation

Fantom Testnet Tokens

1. Add Fantom Testnet to MetaMask: https://chainlist.org/chain/4002

2. Create a MetaMask account and fund it with Fantom Testnet Opera Faucet using https://faucet.fantom.network/.



LINK Tokens

1. Go to https://docs.chain.link/vrf/v2/subscription/supported-networks#fantom-testnet and add Fantom testnet LINK Token to the Metamask wallet.
2. Visit https://faucets.chain.link/fantom-testnet and fund it with Testnet LINKs.



[Foundry](https://getfoundry.sh/) must be installed



## Installation

Create a parent folder

````
mkdir serial-justice
cd serial-justice
````



Clone the repository

````
git clone git@github.com:flokapi/serial-justice-contracts.git
cd serial-justice-foundry
````



Create an `.env ` file and paste the private key of the previously created wallet.

````
PRIVATE_KEY=XXXXXXXXXXXXXXXX
RPC_URL=http://0.0.0.0:8545
SEPOLIA_RPC_URL=XXXXXXXXXXXXXXXX
FANTOM_TESTNET_RPC_URL=https://rpc.ankr.com/fantom_testnet
ETHERSCAN_API_KEY="XXXXXXXXXXXXXXXX"
````



Install the libraries and build the contracts

````
make install
make build
````



## Unit and integration tests

````
make test
````

All tests should pass



## Deployment

Deploy to Fantom Testnet

````
make deploy ARGS="--network fantom-test"
````

Note the subscription ID and save it in the `getFantomTestnetEthConfig`  function from`script/HelperConfig.s.sol`

Congratulations! The DAO with SerialJustice is now deployed on the Fantom test network.

The `MainDAO` contract address will be shown in the logs.

Running `make deploy` also called the `export.py` script, which exports the contract data (last deployment address, ABIs and RPC URL) to a given location, this will be useful to perform SerialJustice simulations on the Fantom Testnet.
