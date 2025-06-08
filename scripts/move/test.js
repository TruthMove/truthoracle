require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0x3651671085d6b9bbb9bcf2c5c97d92dea6504fac33afe8c955c3af3da0d687a1",
    },
  });
}
test();
