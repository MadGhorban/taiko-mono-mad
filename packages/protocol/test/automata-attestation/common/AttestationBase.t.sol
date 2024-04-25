// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Test.sol";
import "forge-std/src/console.sol";
import "forge-std/src/StdJson.sol";
import "../../../contracts/verifiers/SgxVerifier.sol";
import "../../../contracts/thirdparty/optimism/Bytes.sol";
import { AutomataDcapV3Attestation } from
    "../../../contracts/automata-attestation/AutomataDcapV3Attestation.sol";
import { P256Verifier } from "p256-verifier/src/P256Verifier.sol";
import { SigVerifyLib } from "../../../contracts/automata-attestation/utils/SigVerifyLib.sol";
import { PEMCertChainLib } from "../../../contracts/automata-attestation/lib/PEMCertChainLib.sol";
import { V3Struct } from "../../../contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol";
import { BytesUtils } from "../../../contracts/automata-attestation/utils/BytesUtils.sol";
import { Base64 } from "solady/src/utils/Base64.sol";
import "../utils/DcapTestUtils.t.sol";
import "../utils/V3QuoteParseUtils.t.sol";

contract AttestationBase is Test, DcapTestUtils, V3QuoteParseUtils {
    using BytesUtils for bytes;
    using stdJson for string;

    AutomataDcapV3Attestation attestation;
    SigVerifyLib sigVerifyLib;
    P256Verifier p256Verifier;
    PEMCertChainLib pemCertChainLib;
    // use a network that where the P256Verifier contract exists
    // ref: https://github.com/daimo-eth/p256-verifier
    //string internal rpcUrl = vm.envString("RPC_URL");
    string internal tcbInfoPath = "/test/automata-attestation/assets/0923/tcbInfo_00606A000000.json";
    string internal idPath = "/test/automata-attestation/assets/0923/identity.json";
    address constant admin = address(1);
    address constant user = 0x0926b716f6aEF52F9F3C3474A2846e1Bf1ACedf6;
    bytes32 mrEnclave = 0x46049af725ec3986eeb788693df7bc5f14d3f2705106a19cd09b9d89237db1a0;
    bytes32 mrSigner = 0xef69011f29043f084e99ce420bfebdfa410aee1e132014e7ceff29efa9659bd9;

    bytes sampleQuote =
        hex"03000200000000000a000f00939a7233f79c4ca9940a0db3957f060712ce6af1e4a81e0ecdac427b99bb0295000000000b0b100fffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000e700000000000000ae9bd17e36f8bf636cb03fc2a63873ee8d0887fdd596ca6144f82cfa0ee3262000000000000000000000000000000000000000000000000000000000000000001d3d2b8e78a9081c4d7865026f984b265197696dfe4a0598a2d0ef0764f700f500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c2d4564358139c90c17b744fe837f4ddc503eedf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ca1000006399514fd6f9487da072276f760326510efe4277b9a7d9bf6c4d44c54e277a9fae1f09b711bf62c2d40596626184709b8b58f692b5bd3351dfa59dda19794f33c7277e139f5f2982256989fb65198701d836f8d6f15256ff05d4891bcadae813757a7c09fd1ce02297783baf66b9d97662b5fc38053c34970280bea0eb6e1a7e0b0b100fffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000001500000000000000e70000000000000096b347a64e5a045e27369c26e6dcda51fd7c850e9b3a3a79e718f43261dee1e400000000000000000000000000000000000000000000000000000000000000008c4f5775d796503e96137f77c68a829a0056ac8ded70140b081b094490c57bff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000035b9ea12f4cf90ec68e8f4b0cbeb15ab6c70e858f1ed8b00c6f3b8471bf1146600000000000000000000000000000000000000000000000000000000000000005ec0f952f3ef6572b1dfa26bbd07e36d47bff6cfa731c726bd977f93beda6edf836944a8ddd88f3809ab8746a1875cf13089e481d8c36275d1fb71f5837c58f12000000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f0500620e00002d2d2d2d2d424547494e2043455254494649434154452d2d2d2d2d0a4d494945387a4343424a6d674177494241674956414c7a2b6a596a7863582b664a6f6d415562434a71676966496f6c364d416f4743437147534d343942414d430a4d484178496a416742674e5642414d4d47556c756447567349464e4857434251513073675547786864475a76636d306751304578476a415942674e5642416f4d0a45556c756447567349454e76636e4276636d4630615739754d5251774567594456515148444174545957353059534244624746795954454c4d416b47413155450a4341774351304578437a414a42674e5642415954416c56544d4234584454497a4d4467794f4445784d544d774e566f5844544d774d4467794f4445784d544d770a4e566f77634445694d434147413155454177775a535735305a5777675530645949464244537942445a584a3061575a70593246305a5445614d426747413155450a43677752535735305a577767513239796347397959585270623234784644415342674e564241634d43314e68626e526849454e7359584a684d517377435159440a5651514944414a445154454c4d416b474131554542684d4356564d775754415442676371686b6a4f5051494242676771686b6a4f50514d4242774e43414151790a734153725336726b656a31344866314a537075504f314e445556797a5842437670316834324631305555304146555767315934386f6542673774764e355832490a54474542357a48426a7a6a76396b755779556a556f344944446a434341776f77487759445652306a42426777466f41556c5739647a62306234656c4153636e550a3944504f4156634c336c5177617759445652306642475177596a42676f46366758495a616148523063484d364c79396863476b7564484a316333526c5a484e6c0a636e5a705932567a4c6d6c75644756734c6d4e766253397a5a3367765932567964476c6d61574e6864476c76626939324e4339775932746a636d772f593245390a6347786864475a76636d306d5a57356a62325270626d63395a4756794d42304741315564446751574242525456365a6c7a31764a6b5953666b4a6a384e69667a0a716761775744414f42674e56485138424166384542414d434273417744415944565230544151482f4241497741444343416a734743537147534962345451454e0a41515343416977776767496f4d42344743697147534962345451454e4151454545503547726745637a6f704e626f4d3073493062744145776767466c42676f710a686b69472b453042445145434d4949425654415142677371686b69472b4530424451454341514942437a415142677371686b69472b45304244514543416749420a437a415142677371686b69472b4530424451454341774942417a415142677371686b69472b4530424451454342414942417a415242677371686b69472b4530420a4451454342514943415038774551594c4b6f5a496876684e41513042416759434167442f4d42414743797147534962345451454e41514948416745414d4241470a43797147534962345451454e41514949416745414d42414743797147534962345451454e4151494a416745414d42414743797147534962345451454e4151494b0a416745414d42414743797147534962345451454e4151494c416745414d42414743797147534962345451454e4151494d416745414d42414743797147534962340a5451454e4151494e416745414d42414743797147534962345451454e4151494f416745414d42414743797147534962345451454e41514950416745414d4241470a43797147534962345451454e41514951416745414d42414743797147534962345451454e415149524167454e4d42384743797147534962345451454e415149530a4242414c43774d442f2f38414141414141414141414141414d42414743697147534962345451454e41514d45416741414d42514743697147534962345451454e0a4151514542674267616741414144415042676f71686b69472b45304244514546436745424d42344743697147534962345451454e415159454545574a7a4f76790a5a45384b336b6a2f48685845612f73775241594b4b6f5a496876684e41513042427a41324d42414743797147534962345451454e415163424151482f4d4241470a43797147534962345451454e415163434151482f4d42414743797147534962345451454e415163444151482f4d416f4743437147534d343942414d43413067410a4d45554349427133767832444e616d5142466d55644d652b6d5059454375383458676f4643674977534a5634634a61544169454134337037747277423830732b0a32697761686d4464416e434d774a56504c69534575774451463856456753773d0a2d2d2d2d2d454e442043455254494649434154452d2d2d2d2d0a2d2d2d2d2d424547494e2043455254494649434154452d2d2d2d2d0a4d4949436c6a4343416a32674177494241674956414a567658633239472b487051456e4a3150517a7a674658433935554d416f4743437147534d343942414d430a4d476778476a415942674e5642414d4d45556c756447567349464e48574342536232393049454e424d526f77474159445651514b4442464a626e526c624342440a62334a7762334a6864476c76626a45554d424947413155454277774c553246756447456751327868636d4578437a414a42674e564241674d416b4e424d5173770a435159445651514745774a56557a4165467730784f4441314d6a45784d4455774d5442614677307a4d7a41314d6a45784d4455774d5442614d484178496a41670a42674e5642414d4d47556c756447567349464e4857434251513073675547786864475a76636d306751304578476a415942674e5642416f4d45556c75644756730a49454e76636e4276636d4630615739754d5251774567594456515148444174545957353059534244624746795954454c4d416b474131554543417743513045780a437a414a42674e5642415954416c56544d466b77457759484b6f5a497a6a3043415159494b6f5a497a6a304441516344516741454e53422f377432316c58534f0a3243757a7078773734654a423732457944476757357258437478327456544c7136684b6b367a2b5569525a436e71523770734f766771466553786c6d546c4a6c0a65546d693257597a33714f42757a43427544416642674e5648534d4547444157674251695a517a575770303069664f44744a5653763141624f536347724442530a42674e5648523845537a424a4d45656752614244686b466f64485277637a6f764c324e6c636e52705a6d6c6a5958526c63793530636e567a6447566b633256790a646d6c6a5a584d75615735305a577775593239744c306c756447567355306459556d397664454e424c6d526c636a416442674e5648513445466751556c5739640a7a62306234656c4153636e553944504f4156634c336c517744675944565230504151482f42415144416745474d42494741315564457745422f7751494d4159420a4166384341514177436759494b6f5a497a6a30454177494452774177524149675873566b6930772b6936565947573355462f32327561586530594a446a3155650a6e412b546a44316169356343494359623153416d4435786b66545670766f34556f79695359787244574c6d5552344349394e4b7966504e2b0a2d2d2d2d2d454e442043455254494649434154452d2d2d2d2d0a2d2d2d2d2d424547494e2043455254494649434154452d2d2d2d2d0a4d4949436a7a4343416a53674177494241674955496d554d316c71644e496e7a6737535655723951477a6b6e42717777436759494b6f5a497a6a3045417749770a614445614d4267474131554541777752535735305a5777675530645949464a766233516751304578476a415942674e5642416f4d45556c756447567349454e760a636e4276636d4630615739754d5251774567594456515148444174545957353059534244624746795954454c4d416b47413155454341774351304578437a414a0a42674e5642415954416c56544d423458445445344d4455794d5445774e4455784d466f58445451354d54497a4d54497a4e546b314f566f77614445614d4267470a4131554541777752535735305a5777675530645949464a766233516751304578476a415942674e5642416f4d45556c756447567349454e76636e4276636d46300a615739754d5251774567594456515148444174545957353059534244624746795954454c4d416b47413155454341774351304578437a414a42674e56424159540a416c56544d466b77457759484b6f5a497a6a3043415159494b6f5a497a6a3044415163445167414543366e45774d4449595a4f6a2f69505773437a61454b69370a314f694f534c52466857476a626e42564a66566e6b59347533496a6b4459594c304d784f346d717379596a6c42616c54565978465032734a424b357a6c4b4f420a757a43427544416642674e5648534d4547444157674251695a517a575770303069664f44744a5653763141624f5363477244425342674e5648523845537a424a0a4d45656752614244686b466f64485277637a6f764c324e6c636e52705a6d6c6a5958526c63793530636e567a6447566b63325679646d6c6a5a584d75615735300a5a577775593239744c306c756447567355306459556d397664454e424c6d526c636a416442674e564851344546675155496d554d316c71644e496e7a673753560a55723951477a6b6e4271777744675944565230504151482f42415144416745474d42494741315564457745422f7751494d4159424166384341514577436759490a4b6f5a497a6a3045417749445351417752674968414f572f35516b522b533943695344634e6f6f774c7550524c735747662f59693747535839344267775477670a41694541344a306c72486f4d732b586f356f2f7358364f39515778485241765a55474f6452513763767152586171493d0a2d2d2d2d2d454e442043455254494649434154452d2d2d2d2d0a00";

    function initialSetup() public {
        // pinned September 23rd, 2023, 0221 UTC
        // comment this line out if you are replacing sampleQuote with your own
        // this line is needed to bypass expiry reverts for stale quotes
        vm.warp(1_695_435_682);

        vm.deal(admin, 100 ether);

        vm.startPrank(admin);
        p256Verifier = new P256Verifier();
        sigVerifyLib = new SigVerifyLib(address(p256Verifier));
        pemCertChainLib = new PEMCertChainLib();
        attestation = new AutomataDcapV3Attestation(address(sigVerifyLib), address(pemCertChainLib));

        setMrEnclave(address(attestation), mrEnclave);
        setMrSigner(address(attestation), mrSigner);

        string memory tcbInfoJson = vm.readFile(string.concat(vm.projectRoot(), tcbInfoPath));
        string memory enclaveIdJson = vm.readFile(string.concat(vm.projectRoot(), idPath));

        (bool tcbParsedSuccess, TCBInfoStruct.TCBInfo memory parsedTcbInfo) =
            parseTcbInfoJson(tcbInfoJson);
        require(tcbParsedSuccess, "tcb parsed failed");
        string memory fmspc = LibString.lower(parsedTcbInfo.fmspc);
        attestation.configureTcbInfoJson(fmspc, parsedTcbInfo);

        configureQeIdentityJson(address(attestation), enclaveIdJson);
        vm.stopPrank();
    }

    function setMrEnclave(address _attestationAddress, bytes32 _mrEnclave) internal {
        AutomataDcapV3Attestation(_attestationAddress).setMrEnclave(_mrEnclave, true);
    }

    function setMrSigner(address _attestationAddress, bytes32 _mrSigner) internal {
        AutomataDcapV3Attestation(_attestationAddress).setMrSigner(_mrSigner, true);
    }

    function configureQeIdentityJson(
        address _attestationAddress,
        string memory _enclaveIdJson
    )
        internal
    {
        (bool qeIdParsedSuccess, EnclaveIdStruct.EnclaveId memory parsedEnclaveId) =
            parseEnclaveIdentityJson(_enclaveIdJson);
        AutomataDcapV3Attestation(_attestationAddress).configureQeIdentityJson(parsedEnclaveId);
        console.log("qeIdParsedSuccess: %s", qeIdParsedSuccess);
    }

    function configureTcbInfoJson(
        address _attestationAddress,
        string memory _tcbInfoJson
    )
        internal
    {
        (bool tcbParsedSuccess, TCBInfoStruct.TCBInfo memory parsedTcbInfo) =
            parseTcbInfoJson(_tcbInfoJson);
        string memory fmspc = LibString.lower(parsedTcbInfo.fmspc);
        AutomataDcapV3Attestation(_attestationAddress).configureTcbInfoJson(fmspc, parsedTcbInfo);
        console.log("tcbParsedSuccess: %s", tcbParsedSuccess);
    }

    function parsedQuoteAttestation(bytes memory v3QuoteBytes)
        internal
        returns (V3Struct.ParsedV3QuoteStruct memory v3quote)
    {
        v3quote = ParseV3QuoteBytes(address(pemCertChainLib), v3QuoteBytes);
        (bool verified,) = attestation.verifyParsedQuote(v3quote);
        assertTrue(verified);
    }

    function registerSgxInstanceWithQuoteBytes(
        address _pemCertChainLibAddr,
        address _sgxVerifier,
        bytes memory _v3QuoteBytes
    )
        internal
    {
        // console.logBytes(_v3QuoteBytes);
        V3Struct.ParsedV3QuoteStruct memory v3quote =
            ParseV3QuoteBytes(_pemCertChainLibAddr, _v3QuoteBytes);

        address regInstanceAddr =
            address(bytes20(Bytes.slice(v3quote.localEnclaveReport.reportData, 0, 20)));
        console.log("[log] register sgx instance address: %s", regInstanceAddr);
        uint256 sgxIdx = SgxVerifier(_sgxVerifier).registerInstance(v3quote);
        console.log("[log] register sgx instance index: %s", sgxIdx);
    }
}