// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "ControllersRootViewController.h"

#import "Core/Config/MainSettings.h"
#import "Core/Config/WiimoteSettings.h"
#import "Core/HW/Wiimote.h"

#import "ControllersPortViewController.h"
#import "ControllersSettingsUtil.h"
#import "DOLControllerPortType.h"
#import "LocalizationUtil.h"

#include <sstream>
#include <string>

#include "Common/StringUtil.h"
#include "InputCommon/ControllerInterface/DualShockUDPClient/DualShockUDPClient.h"

@interface ControllersRootViewController ()

@end

@implementation ControllersRootViewController {
  DOLControllerPortType _targetType;
  int _targetPort;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  NSString* gamecubeString = DOLCoreLocalizedStringWithArgs(@"Port %1", @"d");
  NSString* wiiString = DOLCoreLocalizedStringWithArgs(@"Wii Remote %1", @"d");
  
  for (int i = 0; i < 4; i++) {
    ControllersRootPortCell* gamecubeCell = self.gamecubeCells[i];
    gamecubeCell.portLabel.text = [NSString stringWithFormat:gamecubeString, i + 1];
    
    ControllersRootPortCell* wiiCell = self.wiiCells[i];
    wiiCell.portLabel.text = [NSString stringWithFormat:wiiString, i + 1];
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  for (int i = 0; i < 4; i++) {
    const SerialInterface::SIDevices siDevice = Config::Get(Config::GetInfoForSIDevice(i));
    
    ControllersRootPortCell* gamecubeCell = self.gamecubeCells[i];
    gamecubeCell.typeLabel.text = [ControllersSettingsUtil getLocalizedStringForSIDevice:siDevice];
    
    WiimoteSource wiiSource = Config::Get(Config::GetInfoForWiimoteSource(i));
    
    ControllersRootPortCell* wiiCell = self.wiiCells[i];
    wiiCell.typeLabel.text = [ControllersSettingsUtil getLocalizedStringForWiimoteSource:wiiSource];
  }

  NSIndexPath* dsuIndexPath = [NSIndexPath indexPathForRow:0 inSection:2];
  UITableViewCell* dsuCell = [self.tableView cellForRowAtIndexPath:dsuIndexPath];
  if (dsuCell) {
    const auto servers_setting = Config::Get(ciface::DualShockUDPClient::Settings::SERVERS);
    const auto server_infos = SplitString(servers_setting, ';');

    std::string current_server_ip;
    int current_port = ciface::DualShockUDPClient::DEFAULT_SERVER_PORT;
    for (const auto& server_info : server_infos) {
      const auto parts = SplitString(server_info, ':');
      if (parts.size() >= 3) {
        current_server_ip = parts[1];
        current_port = std::stoi(parts[2]);
        break;
      }
    }

    if (current_server_ip.empty()) {
      dsuCell.detailTextLabel.text = @"Not configured";
    } else {
      dsuCell.detailTextLabel.text =
          [NSString stringWithFormat:@"%s:%d", current_server_ip.c_str(), current_port];
    }
  }
}

- (void)showDSUClientSettings {
  const auto servers_setting = Config::Get(ciface::DualShockUDPClient::Settings::SERVERS);
  const auto server_infos = SplitString(servers_setting, ';');

  std::string current_server_ip;
  int current_port = ciface::DualShockUDPClient::DEFAULT_SERVER_PORT;
  for (const auto& server_info : server_infos) {
    const auto parts = SplitString(server_info, ':');
    if (parts.size() >= 3) {
      current_server_ip = parts[1];
      current_port = std::stoi(parts[2]);
      break;
    }
  }

  UIAlertController* alert =
      [UIAlertController alertControllerWithTitle:@"DSU Client"
                                          message:@"Enter the DSU server IP and port."
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.placeholder = @"Server IP";
    textField.text = [NSString stringWithUTF8String:current_server_ip.c_str()];
    textField.keyboardType = UIKeyboardTypeURL;
  }];

  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.placeholder = @"Port";
    textField.text = [NSString stringWithFormat:@"%d", current_port];
    textField.keyboardType = UIKeyboardTypeNumberPad;
  }];

  UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil];
  UIAlertAction* saveAction = [UIAlertAction actionWithTitle:@"Save"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction* action) {
                                                      UITextField* ipField = alert.textFields.firstObject;
                                                      UITextField* portField = alert.textFields.lastObject;
                                                      const std::string server_ip =
                                                          ipField.text.length > 0 ?
                                                              std::string([ipField.text UTF8String]) :
                                                              std::string{};
                                                      const int port = std::max(1, std::min(65535, portField.text.intValue));

                                                      std::ostringstream server_stream;
                                                      server_stream << "DSU:" << server_ip << ':' << port << ';';
                                                      Config::SetBaseOrCurrent(
                                                          ciface::DualShockUDPClient::Settings::SERVERS,
                                                          server_stream.str());
                                                      Config::SetBaseOrCurrent(
                                                          ciface::DualShockUDPClient::Settings::SERVERS_ENABLED,
                                                          true);

                                                      NSIndexPath* dsuIndexPath =
                                                          [NSIndexPath indexPathForRow:0 inSection:2];
                                                      UITableViewCell* dsuCell =
                                                          [self.tableView cellForRowAtIndexPath:dsuIndexPath];
                                                      if (dsuCell) {
                                                        dsuCell.detailTextLabel.text =
                                                            [NSString stringWithFormat:@"%s:%d",
                                                                                       server_ip.c_str(),
                                                                                       port];
                                                      }
                                                      [self.tableView reloadData];
                                                    }];

  [alert addAction:cancelAction];
  [alert addAction:saveAction];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  if (indexPath.section == 2 && indexPath.row == 0) {
    [self showDSUClientSettings];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    return;
  }

  if (indexPath.section == 0) {
    _targetType = DOLControllerPortTypePad;
  } else if (indexPath.section == 1) {
    _targetType = DOLControllerPortTypeWiimote;
  } else {
    // The storyboard will handle any segues.
    return;
  }
  
  _targetType = indexPath.section == 0 ? DOLControllerPortTypePad : DOLControllerPortTypeWiimote;
  _targetPort = (int)indexPath.row;
  
  [self performSegueWithIdentifier:@"toPort" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue*)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"toPort"]) {
    ControllersPortViewController* portController = segue.destinationViewController;
    
    portController.portType = _targetType;
    portController.portNumber = _targetPort;
  }
}

@end
