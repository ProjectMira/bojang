# Sign in with Apple — follow-up drafts (November 2026)

Status on 2026-11-13: Apple has not answered on any channel.
- DTS case 22654569 (dts-help@apple.com, from ta6tsering@gmail.com): only automatic acknowledgements.
- Feedback FB25056179: Resolution "Open", Recent Similar Reports "None", no Apple messages.
  The only attachment is the text device log. It has **no sysdiagnose**.
- Forum thread 837986: our Oct post has no reply.

Fill in the `[brackets]` after capturing the sysdiagnose, then send in this order: 1, 2, 3.

---

## 0. Capture the sysdiagnose first

1. On the iPhone, install the **Accounts/AuthKit** logging profile from
   https://developer.apple.com/bug-reporting/profiles-and-logs/ and restart the phone.
2. Open Bojang from TestFlight (build 2.1.2 (46)), tap Sign in with Apple, then Continue.
   Wait for "Sign Up Not Completed". **Note the time.**
3. Within a minute, press and release **both volume buttons and the side button together**.
4. After about 10 minutes, go to Settings → Privacy & Security → Analytics & Improvements →
   Analytics Data. Find `sysdiagnose_…tar.gz`, then AirDrop it to the Mac.

---

## 1. Feedback Assistant comment on FB25056179

Paste into "Add more information" and attach the sysdiagnose with the paperclip.

> Adding the sysdiagnose requested in Developer Forums thread 801173.
>
> - sysdiagnose: attached, captured with the Accounts/AuthKit logging profile installed
> - Failure time: [YYYY-MM-DD HH:MM] UTC
> - Affected Apple Account: [Apple ID used for the test]
> - Device: [iPhone model], iOS [version]
> - Team ID: W66Z24ZPWQ
> - Client ID / App ID: com.bojang.app (primary App ID, identifier VKS273UBYR)
> - Build: TestFlight 2.1.2 (46)
> - Related: DTS case 22654569, forum thread 837986
>
> The failure is still the same as in the original report. The native sheet shows "Sign Up Not
> Completed", and akd logs "AKSQLError -6003 / No applications were found with the provided
> Client ID", then "M2 missing" and AKAuthenticationServerError -24000.
> Another App ID in the same team (app.drokpo.ios) completes Sign in with Apple on the same device
> with the same Apple Account. The Sign in with Apple registration for com.bojang.app seems to be
> missing on the server side. Could it please be repaired? We can retest the unchanged build
> right away.

---

## 2. Reply to the DTS email (case 22654569)

Reply to the "DTS Auto-Acknowledgement: Sign in with Apple …" email from dts-help@apple.com
in ta6tsering@gmail.com. Keep the subject line as it is, and keep the Case-ID line at the top.

> Case-ID: 22654569
>
> Hello,
>
> I'm following up on this request from October 4. We have not heard back yet, and the problem
> has not changed.
>
> As requested in Developer Forums thread 801173, I have now attached a sysdiagnose captured with
> the Accounts/AuthKit logging profile to Feedback FB25056179.
> - Failure time: [YYYY-MM-DD HH:MM] UTC
> - Affected Apple Account: [Apple ID used for the test]
>
> Summary: Team W66Z24ZPWQ, App ID com.bojang.app. Sign in with Apple fails for every user with
> "Sign Up Not Completed". akd reports "AKSQLError -6003: No applications were found with the
> provided Client ID", followed by AKAuthenticationServerError -24000. The entitlement and
> provisioning profile are verified. app.drokpo.ios in the same team works on the same device and
> Apple Account. This matches forum thread 837986, where Apple fixed affected App IDs on the
> server side (for example teams GW7XA5CX69 and FRL3DTJQ62) with no client change.
>
> Our App Store release has been blocked since July. App Review has rejected us twice under
> Guideline 2.1(a) for this. Could you please forward this case to the team that repairs Sign in
> with Apple registrations, or tell us what else you need from us?
>
> Thank you,
> Tashi Tsering

---

## 3. Forum reply on thread 837986

Post as a reply at https://developer.apple.com/forums/thread/837986 (signed in as ta4tsering).

> @Paris X Pinkney, here is a follow-up for Team W66Z24ZPWQ, App ID com.bojang.app. It is still
> failing as of [date], with the same signature: AKSQLError -6003 "No applications were found with
> the provided Client ID", then AKAuthenticationServerError -24000.
>
> As requested in thread 801173, FB25056179 now includes a sysdiagnose captured with the
> Accounts/AuthKit profile, plus the affected Apple Account and the failure time.
> DTS case: 22654569.
>
> app.drokpo.ios in the same team works on the same device and Apple Account, so only this App ID's
> server-side registration seems to be affected. Could the same repair you made for GW7XA5CX69 and
> FRL3DTJQ62 be made for com.bojang.app? We can retest the unchanged build right away.
> Thank you.
