package main

import (
	"context"
	crand "crypto/rand"
	"fmt"
	"io/ioutil"
	"sync"
	"testing"
	"time"

	"codanet"

	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/host"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	protocol "github.com/libp2p/go-libp2p-core/protocol"

	"github.com/libp2p/go-libp2p-pubsub"
	ma "github.com/multiformats/go-multiaddr"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/stretchr/testify/require"
	ipc "libp2p_ipc"
)

var (
	testTimeout  = 10 * time.Second
	testProtocol = protocol.ID("/mina/")
)

var testPort uint16 = 7000
var testPortMutex sync.Mutex

func newTestKey(t *testing.T) crypto.PrivKey {
	r := crand.Reader
	key, _, err := crypto.GenerateEd25519Key(r)
	require.NoError(t, err)

	return key
}

func testStreamHandler(_ net.Stream) {}

func newTestAppWithMaxConns(t *testing.T, seeds []peer.AddrInfo, noUpcalls bool, maxConns int, port uint16) *app {
	dir, err := ioutil.TempDir("", "mina_test_*")
	require.NoError(t, err)

	addr, err := ma.NewMultiaddr(fmt.Sprintf("/ip4/0.0.0.0/tcp/%d", port))
	require.NoError(t, err)

	helper, err := codanet.MakeHelper(context.Background(),
		[]ma.Multiaddr{addr},
		nil,
		dir,
		newTestKey(t),
		string(testProtocol),
		seeds,
		codanet.NewCodaGatingState(nil, nil, nil, nil),
		maxConns,
		true,
	)
	require.NoError(t, err)

	helper.GatingState.TrustedAddrFilters = ma.NewFilters()
	helper.Host.SetStreamHandler(testProtocol, testStreamHandler)

	t.Cleanup(func() {
		err := helper.Host.Close()
		if err != nil {
			panic(err)
		}
	})

	return &app{
		P2p:                      helper,
		Ctx:                      context.Background(),
		Subs:                     make(map[uint64]subscription),
		Topics:                   make(map[string]*pubsub.Topic),
		ValidatorMutex:           &sync.Mutex{},
		Validators:               make(map[uint64]*validationStatus),
		Streams:                  make(map[uint64]net.Stream),
		AddedPeers:               make([]peer.AddrInfo, 0, 512),
		OutChan:                  make(chan *capnp.Message, 64),
		MetricsRefreshTime:       time.Second * 2,
		NoUpcalls:                noUpcalls,
		metricsServer:            nil,
		metricsCollectionStarted: false,
	}
}

func nextPort() uint16 {
	testPortMutex.Lock()
	testPort++
	defer testPortMutex.Unlock()
	return testPort
}

func newTestApp(t *testing.T, seeds []peer.AddrInfo, noUpcalls bool) (*app, uint16) {
	port := nextPort()
	return newTestAppWithMaxConns(t, seeds, noUpcalls, 50, port), port
}

func addrInfos(h host.Host) (addrInfos []peer.AddrInfo, err error) {
	for _, multiaddr := range multiaddrs(h) {
		addrInfo, err := peer.AddrInfoFromP2pAddr(multiaddr)
		if err != nil {
			return nil, err
		}
		addrInfos = append(addrInfos, *addrInfo)
	}
	return addrInfos, nil
}

func multiaddrs(h host.Host) (multiaddrs []ma.Multiaddr) {
	addrs := h.Addrs()
	for _, addr := range addrs {
		multiaddr, err := ma.NewMultiaddr(fmt.Sprintf("%s/p2p/%s", addr, h.ID()))
		if err != nil {
			continue
		}
		multiaddrs = append(multiaddrs, multiaddr)
	}
	return multiaddrs
}

func checkRpcResponseError(t *testing.T, resMsg *capnp.Message) (uint64, string) {
	msg, err := ipc.ReadRootDaemonInterface_Message(resMsg)
	require.NoError(t, err)
	require.True(t, msg.HasRpcResponse())
	resp, err := msg.RpcResponse()
	require.NoError(t, err)
	require.True(t, resp.HasError())
	header, err := resp.Header()
	require.NoError(t, err)
	seqno := header.SeqNumber()
	respError, err := resp.Error()
	require.NoError(t, err)
	return seqno, respError
}

func checkRpcResponseSuccess(t *testing.T, resMsg *capnp.Message) (uint64, ipc.Libp2pHelperInterface_RpcResponseSuccess) {
	msg, err := ipc.ReadRootDaemonInterface_Message(resMsg)
	require.NoError(t, err)
	require.True(t, msg.HasRpcResponse())
	resp, err := msg.RpcResponse()
	require.NoError(t, err)
	require.True(t, resp.HasSuccess())
	header, err := resp.Header()
	require.NoError(t, err)
	seqno := header.SeqNumber()
	respSuccess, err := resp.Success()
	require.NoError(t, err)
	return seqno, respSuccess
}

func mkPeerInfo(t *testing.T, app *app, appPort uint16) codaPeerInfo {
	expectedHost, err := app.P2p.Host.Addrs()[0].ValueForProtocol(4)
	require.NoError(t, err)
	return codaPeerInfo{
		Libp2pPort: appPort,
		Host:       expectedHost,
		PeerID:     app.P2p.Host.ID().String(),
	}
}
