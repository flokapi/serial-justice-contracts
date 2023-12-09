from pathlib import Path
import shutil
import json
import os


EXPORT_PATH = "../serial-justice-simulation/env"
MAIN_CONTRACT_NAME = "MainDAO"
EXPORTED_CONTRACTS = ["MainDAO", "SerialJustice", "JusticeToken"]


CHAIN_ID_DIR = f"broadcast/Deploy{MAIN_CONTRACT_NAME}.s.sol/"
DEPLOYMENT_FILE_PATH = "broadcast/Deploy{}.s.sol/{}/run-latest.json"
RPC_URL_FILE_PATH = "cache/Deploy{}.s.sol/{}/run-latest.json"


def export_abi(_contract_name):
    src = f"out/{_contract_name}.sol/{_contract_name}.json"
    dst = f"{EXPORT_PATH}/abi/"
    shutil.copy(src, dst)


def get_chain_ids():
    return os.listdir(CHAIN_ID_DIR)


def extract_last_deployment_address(_contract_name, _chain_id):
    deployment_file_path = DEPLOYMENT_FILE_PATH.format(
        _contract_name, _chain_id)
    with open(deployment_file_path) as f:
        data = json.loads(f.read())

    for transaction in data["transactions"]:
        if transaction["contractName"] == _contract_name:
            return transaction["contractAddress"]


def extract_last_rpc_url(_contract_name, _chain_id):
    rpc_url_file_path = RPC_URL_FILE_PATH.format(_contract_name, _chain_id)
    with open(rpc_url_file_path) as f:
        data = json.loads(f.read())

    return data["transactions"][0]["rpc"]


def export_config():
    config = {}
    for chain_id in get_chain_ids():
        contract_address = extract_last_deployment_address(
            MAIN_CONTRACT_NAME, chain_id)
        rpc_url = extract_last_rpc_url(MAIN_CONTRACT_NAME, chain_id)

        config[chain_id] = {
            "contract_address": contract_address, "rpc_url": rpc_url}

    configPath = Path(EXPORT_PATH).joinpath("config.json")
    with open(configPath, "w+") as f:
        f.write(json.dumps(config))


def main():
    print(f"Exporting to {EXPORT_PATH}")

    Path(EXPORT_PATH).joinpath("abi").mkdir(parents=True, exist_ok=True)

    for contract_name in EXPORTED_CONTRACTS:
        export_abi(contract_name)

    export_config()


if __name__ == "__main__":
    main()
