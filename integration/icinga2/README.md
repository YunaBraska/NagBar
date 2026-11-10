# Icinga 2 Integration Lab

This lab runs the real official Icinga 2 image. It is external-system test
infrastructure, not a production fake server.

The image is pinned to the multi-platform Icinga 2.16 digest. The lab exposes
only `127.0.0.1:5665`, uses Icinga's generated private CA, and provides:

- a least-privilege Basic-auth API user;
- a least-privilege X.509 client-certificate API user;
- an authenticated user without object permissions;
- healthy and failing host/service objects;
- generated CA and PKCS#12 artifacts outside the repository.

Create `integration/icinga2/.env.local` from `.env.example`, then run:

```sh
./script/icinga2_lab.sh start
./script/icinga2_lab.sh verify
./script/icinga2_lab.sh stop
```

`start` also creates a `nagbar-client` identity signed by the lab CA. The
PKCS#12 file and CA certificate are written to
`NAGBAR_ICINGA_ARTIFACTS_DIR`. The PKCS#12 password remains only in the ignored
`.env.local` file.

The matrix intentionally treats plain HTTP and no authentication as negative
tests because the Icinga 2 API requires HTTPS and authentication. It also proves
that the lab's private CA is rejected without an explicit trust decision.
