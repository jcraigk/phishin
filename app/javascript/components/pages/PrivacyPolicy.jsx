import React from "react";
import PageWrapper from "./PageWrapper";

const PrivacyPolicy = () => {
  return (
    <PageWrapper>
      <h1 className="title">Privacy Policy</h1>
      <p><em>Last updated: March 10, 2026</em></p>

      <p>
        Phish.in (&quot;we&quot;, &quot;us&quot;, &quot;our&quot;) is a community archive of live Phish
        audience recordings. This policy covers the Phish.in website, API, and all MCP
        integrations including the Subtle Sounds ChatGPT app and the Phish.in Claude app
        (both powered by the Phish.in MCP server).
      </p>

      <h3>Data We Collect</h3>

      <h4>Website Accounts</h4>
      <p>
        When you sign in via Google OAuth, we store your email address, display name, and
        authentication tokens solely to maintain your account. No other Google profile data is
        accessed or stored.
      </p>

      <h4>MCP Integrations (Subtle Sounds / Phish.in Claude App)</h4>
      <p>
        The Subtle Sounds ChatGPT app and the Phish.in Claude app both communicate with our MCP
        server at phish.in/mcp. This server is stateless and requires no authentication. We do not
        collect, store, or log any user inputs (such as search queries, song slugs, or parameter
        values) submitted through the MCP server. No conversation content, IP addresses, or device
        identifiers from ChatGPT or Claude users are retained by us. All tool inputs are processed
        in real time and discarded immediately after the response is returned.
      </p>

      <h4>Standard Server Logs</h4>
      <p>
        Our web server may record standard HTTP access logs (IP address, request path, timestamp,
        user agent) for operational and security purposes. These logs are retained for up to 30
        days and are not linked to individual user accounts or ChatGPT sessions.
      </p>

      <h3>How We Use Data</h3>
      <ul>
        <li>Account data is used only to authenticate you and manage your playlists and preferences on Phish.in.</li>
        <li>MCP tool inputs and outputs are used only to fulfill the current request (e.g., returning show data, search results, or audio track information). No inputs or outputs are used for training, analytics, or profiling.</li>
        <li>Server logs are used only for infrastructure monitoring and abuse prevention.</li>
      </ul>

      <h3>Data Sharing</h3>
      <p>
        We do not sell, rent, or share your personal information with any third party. Data is
        never disclosed except where required by law.
      </p>

      <h3>Data Retention</h3>
      <ul>
        <li><strong>Account data:</strong> Retained for as long as your account exists. You may request deletion at any time.</li>
        <li><strong>MCP tool data:</strong> Not retained. All requests are stateless and processed in memory only.</li>
        <li><strong>Server logs:</strong> Retained for up to 30 days, then automatically deleted.</li>
      </ul>

      <h3>User Controls</h3>
      <ul>
        <li>You may delete your Phish.in account and all associated data by contacting us.</li>
        <li>The Subtle Sounds and Phish.in Claude apps require no account and store no user data, so there is nothing to delete on our end.</li>
      </ul>

      <h3>Children</h3>
      <p>
        Our services are not directed at children under 13 and we do not knowingly collect data
        from children.
      </p>

      <h3>Changes to This Policy</h3>
      <p>
        We may update this policy from time to time. Material changes will be noted by updating the
        date at the top of this page.
      </p>

      <h3>Contact</h3>
      <p>
        For questions or data requests, contact us
        at <a href="mailto:phish.in.music@gmail.com">phish.in.music@gmail.com</a>.
      </p>
    </PageWrapper>
  );
};

export default PrivacyPolicy;
