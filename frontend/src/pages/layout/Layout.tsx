import { useContext, useEffect, useState } from 'react'
import { Link, Outlet } from 'react-router-dom'
import { Dialog, Stack, TextField, PrimaryButton, DefaultButton, DialogType, DialogFooter } from '@fluentui/react'
import { CopyRegular } from '@fluentui/react-icons'
import { motion, AnimatePresence } from 'framer-motion'

import { CosmosDBStatus } from '../../api'
import Contoso from '../../assets/Contoso.svg'
import { HistoryButton, ShareButton } from '../../components/common/Button'
import { AppStateContext } from '../../state/AppProvider'

import styles from './Layout.module.css'

// Add version information
const APP_VERSION = 'v1.0.0'

const Layout = () => {
  const [isSharePanelOpen, setIsSharePanelOpen] = useState<boolean>(false)
  const [isDisclaimerOpen, setIsDisclaimerOpen] = useState<boolean>(false)
  const [copyClicked, setCopyClicked] = useState<boolean>(false)
  const [copyText, setCopyText] = useState<string>('Copy URL')
  const [shareLabel, setShareLabel] = useState<string | undefined>('Share')
  const [hideHistoryLabel, setHideHistoryLabel] = useState<string>('Hide chat history')
  const [showHistoryLabel, setShowHistoryLabel] = useState<string>('Show chat history')
  const [logo, setLogo] = useState('')
  const [showLanding, setShowLanding] = useState(true)
  const appStateContext = useContext(AppStateContext)
  const ui = appStateContext?.state.frontendSettings?.ui

  const handleLaunchClick = () => {
    setShowLanding(false)
  }

  const handleShareClick = () => {
    setIsSharePanelOpen(true)
  }

  const handleSharePanelDismiss = () => {
    setIsSharePanelOpen(false)
    setCopyClicked(false)
    setCopyText('Copy URL')
  }

  const handleCopyClick = () => {
    navigator.clipboard.writeText(window.location.href)
    setCopyClicked(true)
  }

  const handleHistoryClick = () => {
    appStateContext?.dispatch({ type: 'TOGGLE_CHAT_HISTORY' })
  }

  const handleDisclaimerClick = () => {
    setIsDisclaimerOpen(true)
  }

  const handleDisclaimerDismiss = () => {
    setIsDisclaimerOpen(false)
  }

  useEffect(() => {
    if (!appStateContext?.state.isLoading) {
      setLogo(ui?.logo || Contoso)
    }
  }, [appStateContext?.state.isLoading])

  useEffect(() => {
    if (copyClicked) {
      setCopyText('Copied URL')
    }
  }, [copyClicked])

  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth < 480) {
        setShareLabel(undefined)
        setHideHistoryLabel('Hide history')
        setShowHistoryLabel('Show history')
      } else {
        setShareLabel('Share')
        setHideHistoryLabel('Hide chat history')
        setShowHistoryLabel('Show chat history')
      }
    }

    window.addEventListener('resize', handleResize)
    handleResize()

    return () => window.removeEventListener('resize', handleResize)
  }, [])

  // Dialog content configuration
  const disclaimerDialogContentProps = {
    type: DialogType.normal,
    title: 'Disclaimer',
    closeButtonAriaLabel: 'Close',
    subText: ''
  }

  return (
    <>
      {showLanding ? (
        <div className={styles.landingPage}>
          <div className={styles.landingContainer}>
            <img
              src="https://yrci-public-ercecudsgcgbfxdt.z01.azurefd.net/assets/AIR-hr_ver3.png"
              alt="AIR-hr"
              className={styles.landingLogo}
            />

            <div className={styles.landingContent}>
              <p className={styles.landingDescription}>
                Developed by experts in AI and federal Human Resource (HR) regulations, the AIR-hr tool simplifies
                complex regulations and provides employees with clear, actionable explanations that help them navigate
                government HR policies effectively. It ensures employees fully understand their options, minimizing
                confusion and improving decision-making.
              </p>

              <button className={styles.launchButton} onClick={handleLaunchClick}>
                Launch
              </button>
            </div>

            <div className={styles.divider} />

            <h2 className={styles.collaborationTitle}>AIR-hr is a collaboration between</h2>

            <div className={styles.partnerLogos}>
              <a
                href="https://pyramidsystems.com"
                target="_blank"
                rel="noopener noreferrer"
                className={styles.partnerLink}>
                <img
                  src="https://yrci-public-ercecudsgcgbfxdt.z01.azurefd.net/assets/psi-logo.png"
                  alt="Pyramid Systems"
                  className={styles.partnerLogo}
                />
              </a>

              <div className={styles.logoSeparator} />

              <a href="https://yrci.com" target="_blank" rel="noopener noreferrer" className={styles.partnerLink}>
                <img
                  src="https://yrci-public-ercecudsgcgbfxdt.z01.azurefd.net/assets/yrci-logo.png"
                  alt="YRCI"
                  className={styles.partnerLogo}
                />
              </a>
            </div>

            <div className={styles.divider} />

            <div className={styles.contactSection}>
              <p className={styles.contactInfo}>Media Contact: media@AIR-hr.ai</p>
              <a href="mailto:media@AIR-hr.ai" className={styles.pressReleaseButton}>
                PRESS RELEASE
              </a>
            </div>
          </div>
        </div>
      ) : (
        <motion.div
          className={styles.layout}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.5 }}>
          <header className={styles.header} role={'banner'}>
            <Stack horizontal verticalAlign="center" horizontalAlign="space-between">
              <Stack horizontal verticalAlign="center">
                <img src={logo} className={styles.headerIcon} aria-hidden="true" alt="" />
                <Link to="/" className={styles.headerTitleContainer}>
                  <h1 className={styles.headerTitle}>{ui?.title}</h1>
                </Link>
              </Stack>
              <Stack horizontal tokens={{ childrenGap: 4 }} className={styles.shareButtonContainer}>
                {appStateContext?.state.isCosmosDBAvailable?.status !== CosmosDBStatus.NotConfigured &&
                  ui?.show_chat_history_button !== false && (
                    <HistoryButton
                      onClick={handleHistoryClick}
                      text={appStateContext?.state?.isChatHistoryOpen ? hideHistoryLabel : showHistoryLabel}
                    />
                  )}
                {ui?.show_share_button && <ShareButton onClick={handleShareClick} text={shareLabel} />}
              </Stack>
            </Stack>
          </header>
          <Outlet />
          <Dialog
            onDismiss={handleSharePanelDismiss}
            hidden={!isSharePanelOpen}
            styles={{
              main: [
                {
                  selectors: {
                    ['@media (min-width: 480px)']: {
                      maxWidth: '600px',
                      background: '#FFFFFF',
                      boxShadow: '0px 14px 28.8px rgba(0, 0, 0, 0.24), 0px 0px 8px rgba(0, 0, 0, 0.2)',
                      borderRadius: '8px',
                      maxHeight: '200px',
                      minHeight: '100px'
                    }
                  }
                }
              ]
            }}
            dialogContentProps={{
              title: 'Share the web app',
              showCloseButton: true
            }}>
            <Stack horizontal verticalAlign="center" style={{ gap: '8px' }}>
              <TextField className={styles.urlTextBox} defaultValue={window.location.href} readOnly />
              <div
                className={styles.copyButtonContainer}
                role="button"
                tabIndex={0}
                aria-label="Copy"
                onClick={handleCopyClick}
                onKeyDown={e => (e.key === 'Enter' || e.key === ' ' ? handleCopyClick() : null)}>
                <CopyRegular className={styles.copyButton} />
                <span className={styles.copyButtonText}>{copyText}</span>
              </div>
            </Stack>
          </Dialog>

          <div className={styles.footerDisclaimerContainer}>
            <button className={styles.footerDisclaimerLink} onClick={handleDisclaimerClick}>
              Disclaimer
            </button>
            <span className={styles.versionInfo}>{APP_VERSION}</span>
          </div>

          <Dialog
            hidden={!isDisclaimerOpen}
            onDismiss={handleDisclaimerDismiss}
            dialogContentProps={disclaimerDialogContentProps}
            minWidth={600}
            maxWidth={800}
            modalProps={{
              isBlocking: true,
              styles: { main: { maxWidth: 800 } }
            }}>
            <div className={styles.disclaimerContent}>
              <p>
                This Human Resource Artificial Intelligence (HR AI) software application provides responses based on
                Title 5 of the Code of Federal Regulations (5 CFR) and is powered by technology developed by Pyramid
                Systems Inc. The system has been trained and informed by subject matter experts from YRCI to enhance
                accuracy and relevance. The information provided by this application is dependent on the most recent
                version of 5 CFR available at the time of inquiry. While every effort is made to ensure the accuracy and
                currency of responses, users should verify information against official regulatory sources. This
                software does not provide legal or authoritative interpretations of federal regulations and should not
                be relied upon as a substitute for professional human resources or legal advice. By using this
                application, users acknowledge that the information is provided on an "as-is" basis and that the
                developers and trainers of this software assume no liability for any decisions made based on its
                responses.
              </p>

              <h3 className={styles.disclaimerSubheading}>Data Privacy & Security</h3>
              <p>
                This application may collect and process user inputs to improve response quality and system performance.
                However, it does not store or share personal information (PI) or sensitive information beyond what is
                necessary for operational functionality. All data handling practices comply with applicable federal and
                state privacy laws and security protocols.
              </p>
              <p>
                Users should refrain from entering confidential, personal, or sensitive information when interacting
                with the system. By using this application, users acknowledge and accept the privacy practices outlined
                above.
              </p>
              <p>
                By continuing to use this application, users agree that the information is provided on an "as-is" basis
                and that the developers and trainers of this software assume no liability for any decisions made based
                on its responses.
              </p>
            </div>

            <DialogFooter>
              <button className={styles.launchButton} onClick={handleDisclaimerDismiss}>
                I Understand
              </button>
            </DialogFooter>
          </Dialog>
        </motion.div>
      )}
    </>
  )
}

export default Layout
